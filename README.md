# Julia

Julia on Ruby.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'julia'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install julia

## Usage

```ruby
require 'julia'

Julia.init(ENV['JULIA_HOME'])
Julia.eval_string('print(pi)')
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/julia.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

