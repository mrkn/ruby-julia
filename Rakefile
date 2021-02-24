require "bundler/gem_helper"
require "rake/extensiontask"

base_dir = File.join(__dir__)

helper = Bundler::GemHelper.new(base_dir)
helper.install
spec = helper.gemspec

Dir[File.expand_path('../tasks/**/*.rake', __FILE__)].each {|f| load f }

Rake::ExtensionTask.new('julia')

desc "Run tests"
task :test do
  cd(base_dir) do
    ruby("test/run-test.rb")
  end
end

task default: :test
task test: :compile
