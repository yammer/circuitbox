require 'rake/testtask'
require "bundler/gem_version_tasks"

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

desc "Run tests"
task :default => :test
