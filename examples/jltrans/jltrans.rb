require "julia"
require "yadriggy"

module JLTrans
  Syntax = Yadriggy::Syntax.ruby_syntax
  Syntax.debug = true  # XXX

  class TypeChecker < Yadriggy::RubyTypeInferer
    def initialize
      super(Syntax)
      @free_variables = {}
    end

    def references
      @free_variables
    end

    def clear_references!
      @free_variables = {}
    end

    # rule(ArrayLiteral)

    # rule(ArrayRef)

    # rule(Binary)

    # rule(Dots)

    # rule(HashLiteral)

    rule(Name) do
      type = proceed(ast, type_env)
      collect_free_variables(ast, type)
      type
    end

    rule(Number) do
      case ast.value
      when Integer
        RubyClass::Integer
      when Float
        RubyClass::Float
      when Complex
        RubyClass::Complex
      when Rational
        RubyClass::Rational
      else
        RubyClass::Numeric
      end
    end

    rule(VariableCall) do
      type = proceed(ast, type_env)
      collect_free_variables(ast, type)
      type
    end

    # Collect free variables.
    # @param [Name|VariableCall] an_ast
    def collect_free_variables(an_ast, type)
      unless Yadriggy::InstanceType.role(type).nil?
        obj = type.object
        case obj
        when Numeric, String, Symbol, Module
          @free_variables[obj] = an_ast.name
        end
      end
    end

    # Computes the type of the {Call} expression
    # by searching the receiver class for the called method.
    # If the method is not found or the method is provided by
    # `Object` or its super class, {DynType} is returned.
    #
    # This overrides the super's method but if the called method is not
    # found, it returns DynType; it does not raise an error.
    def lookup_ruby_classes(type_env, arg_types, recv_type, method_name)
      begin
        mth = Type.get_instance_method_object(recv_type, method_name)
      rescue CheckError
        return DynType
      end
      return_type = resolve_builtin_method_return_type(mth)
      return return_type unless return_type.nil?
      new_tenv = type_env.new_base_tenv(recv_type.exact_type)
      get_return_type(ast, mth, new_tenv, arg_types)
    end

    def resolve_builtin_method_return_type(method)
      owner, name = method.owner, method.name
      if owner == Kernel
        case name
        when :Complex
          return RubyClass::Complex
        when :Float
          return RubyClass::Float
        when :Integer
          return RubyClass::Integer
        when :Rational
          return RubyClass::Rational
        end
      elsif owner == Array
        case name
        when :<<
          return RubyClass::Array
        else
          return DynType
        end
      elsif owner == Range
        case name
        when :each
          return RubyClass::NilClass
        end
      elsif owner > Object
        return DynType
      end
    end
  end

  class CodeGen < Yadriggy::Checker
    def initialize(printer, type_checker, code)
      super()
      @printer = printer
      @type_checker = type_checker
      @code = code
    end

    attr_reader :printer

    attr_reader :type_checker

    rule(ArrayLiteral) do
      @printer << "["
      ast.elements.each_with_index do |e, i|
        @printer << ", " if i > 0
        check(e)
      end
      @printer << "]"
    end

    rule(Assign) do
      if ast.left.is_a?(Array) && ast.right.is_a?(Array) && ast.left.size < ast.right.size
        error!(ast, "too many right operands")
      end

      if ast.left.is_a?(Array)
        ast.left.each.with_index do |e, i|
          next unless e
          @printer << ", " if i > 0
          check_all(e)
          if errors?
            $stderr.puts error_messages
            raise "Julia code generation failure"
          end
        end
      else
        check(ast.left)
      end

      @printer << " " << ast.op << " "

      if ast.right.is_a?(Array)
        ast.right.each.with_index do |e, i|
          next unless e
          @printer << ", " if i > 0
          check_all(e)
          if errors?
            $stderr.puts error_messages
            raise "Julia code generation failure"
          end
        end
      else
        check(ast.right)
      end
    end

    rule(Binary) do
      left_type = @type_checker.type(ast.left)
      if left_type == RubyClass::Array && ast.op == :<<
        @printer << "append!("
        check(ast.left)
        @printer << ", "
        check(ast.right)
        @printer << ")"
      else
        check(ast.left)
        op = ast.op
        op = "^" if op == :**
        @printer << " " << op << " "
        check(ast.right)
      end
    end

    rule(Block) do
      check(ast.body)
    end

    rule(Call) do
      name = julia_function_name(ast)
      if ast.block.nil?
        print_call(ast.receiver, name, ast.args)
      else
        print_call_with_block(ast.receiver, name, ast.args, ast.block)
      end
    end

    rule(Conditional) do
      @printer << "if "
      @printer << "!(" if ast.op == :unless || ast.op == :unless_mod
      check(ast.cond)
      @printer << ")"  if ast.op == :unless || ast.op == :unless_mod

      @printer << :nl
      @printer.down

      check(ast.then)

      if ast.else
        @printer << :nl
        @printer.up
        @printer << "else" << :nl
        @printer.down

        check(ast.else)
      end

      @printer.up
      @printer << "end" << :nl
    end

    rule(Def) do
      def_function(ast, julia_function_name(ast))
    end

    rule(Dots) do
      @printer << "RbCall.RubyRange("
      check(ast.left)
      @printer << ", 1, "
      check(ast.right)
      @printer << ", true" if ast.op == "..."
      @printer << ")"
    end

    rule(Exprs) do
      ast.expressions.each_with_index do |e, i|
        @printer << :nl if i > 0
        check(e)
      end
    end

    rule(Loop) do
      @printer << "while "
      @printer << "!(" if ast.op == :until || ast.op == :until_mod
      check(ast.cond)
      @printer << ")"  if ast.op == :until || ast.op == :until_mod
      @printer << :nl
      @printer.down

      check(ast.body)

      @printer.up
      @printer << "end"
    end

    rule(Name) do
      @printer << ast.name
    end

    rule(Number) do
      case ast.value
      when Complex
        @printer << "#{ast.value.real}+#{ast.value.imag}im"
      when Rational
        @printer << "#{ast.value.numerator}//#{ast.value.denominator}"
      else
        @printer << ast.value.to_s
      end
    end

    rule(Paren) do
      if ast.expression.is_a?(Dots)
        check(ast.expression)
      else
        @printer << "("
        check(ast.expression)
        @printer << ")"
      end
    end

    rule(Return) do
      @printer << "return "
      ast.values.each_with_index do |e, i|
        @printer << ", " if i > 0
        check(e)
      end
    end

    rule(Unary) do
      ast.value
    end

    def preamble
    end

    def julia_function(expr)
      check(expr)
    end

    def julia_function_name(expr)
      case expr
      when Def, Call
        case expr.name.name
        when "Complex"
          return "complex"
        when /\?\z/
          return "#{Regexp.last_match.pre_match}_p"
        when /_p\z/
          return "#{Regexp.last_match.pre_match}_p"
        else
          expr.name.name
        end
      else
        nil  # TODO
      end
    end

    private

    def def_function(expr, fname)
      t = @type_checker.type(expr)

      mt = MethodType.role(t)
      if mt
        parameters(expr, fname, mt)
      else
        error!(expr, "not a function")
      end

      @printer << :nl
      @printer.down

      check(expr.body)

      @printer.up
      @printer << "end" << :nl
    end

    def parameters(expr, fname_str, mtype)
      ret_type = mtype.result_type

      @printer << "function " << fname_str << "("
      param_types = mtype.params
      case param_types
      when Array
        expr.params.each_with_index do |param, i|
          @printer << ", " if i > 0
          @printer << param.name << "::" << julia_type(param_types[i])
        end
      else
        error!(expr, "bad parameter types")
      end
      @printer << ")"
    end

    def print_call(receiver, name, args)
      case name
      when String
        @printer << name
      else
        @printer << name.name
      end

      @printer << "("

      unless receiver.nil?
        check(receiver)
        @printer << ", " if args.length > 0
      end
      args.each_with_index do |a, i|
        @printer << ", " if i > 0
        case a
        when Yadriggy::Unary, Yadriggy::Number
          @printer << a.value
        when Yadriggy::Name
          @printer << a.name
        when Yadriggy::Call
          print_call(nil, a.name, a.args)
        end
      end

      @printer << ")"
    end

    def print_call_with_block(receiver, name, args, block)
      if name == "each"
        return print_each_with_block(receiver, block)
      elsif name == "step" && args.length == 1
        recv_type = @type_checker.type(receiver)
        if CompositeType.role(recv_type)&.ruby_class == RubyClass::Range
          range = receiver.is_a?(Paren) ? receiver.expression : receiver
          step = args[0]
          args = [[:@int,   "1",   [nil, nil]],
                  [:@float, "0.1", [nil, nil]],
                  [:@int,   "2",   [nil, nil]]]
          args << [:@kw, true, [nil, nil]] if range.op == :"..."
          receiver_sexp = [
            :method_add_arg,
            [:fcall, [:@const, "RbCall.RubyRange", [nil, nil]]],
            [:arg_paren, [:args_add_block, args, false]]]
          receiver = ASTree.to_node(receiver_sexp)
          receiver.args[0] = range.left
          receiver.args[1] = step
          receiver.args[2] = range.right
          return print_each_with_block(receiver, block)
        end
      elsif name == "map" && args.length == 0
        if receiver.is_a?(Yadriggy::Call) && receiver.name.name == "step"
          step_recv_type = @type_checker.type(receiver.receiver)
          if CompositeType.role(step_recv_type)&.ruby_class == RubyClass::Range
            range = receiver.receiver
            range = range.expression if range.is_a?(Paren)
            exclude = range.op == :"..."
            step = receiver.args[0]
            # TODO
            return proceed_range_step_map(range.left, step, range.right, exclude, block)
          end
        end
      end
      # TODO
      proceed(ast)
    end

    def proceed_range_step_map(range_beg, step, range_end, excl_p, block, nesting: [])
      # TODO
      proceed(ast)
    end

    def print_each_with_block(receiver, block)
      @printer << "for "

      if block.params.length > 1
        @printer << "("
        block.params.each_with_index do |param, i|
          @printer << ", " if i > 0
          @printer << param.name
        end
        @printer << ")"
      else
        @printer << block.params[0].name
      end

      @printer << " in "
      check(receiver)

      @printer << :nl
      @printer.down

      check(block.body)
      # TODO: rescue

      @printer.up
      @printer << "end"
    end

    def julia_type(type)
      type = type.supertype if InstanceType.role(type)
      if type == RubyClass::Integer || type == Integer
        "Integer"
      elsif type == RubyClass::Float || type == Float
        "Float64"
      elsif type == RubyClass::Rational || type == Rational
        "Rational"
      elsif type == RubyClass::Complex || type == Complex
        "ComplexF64"
      elsif type == RubyClass::String || type == String
        "String"
      else
        "Any"
      end
    end
  end

  def jl_trans(target = nil, dump_jl: false, &block)
    target ||= block
    ast = Yadriggy.reify(target)
    Syntax.raise_error unless Syntax.check(ast.tree)
    checker = TypeChecker.new
    checker.typecheck(ast.tree.body)
    # TODO: init_free_variables(checker)

    printer = Yadriggy::Printer.new(indent=4)
    gen = CodeGen.new(printer, checker, ast)
    gen.preamble

    ast.astrees.each.with_index do |e, i|
      printer << :nl if i > 0
      gen.julia_function(e.tree)
    end

    if dump_jl
      $stderr.puts printer.output
      $stderr.flush
    end

    result = Julia.eval(printer.output)

    case target
    when Proc
      return result
    else Method
      name = target.name.to_s
      jl_func = Julia.eval(name)
      define_method(name) do |*args, **kwargs|
        jl_func.(*args, **kwargs)
      end
    end
  end
end
