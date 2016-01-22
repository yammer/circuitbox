require 'rake/testtask'
require "bundler/gem_version_tasks"

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
end

desc "run the circuitbox benchmark scripts"
task :benchmark do
  benchmark_scripts = FileList.new("./benchmark/*_benchmark.rb")
  benchmark_scripts.each do |script|
    system "bundle exec ruby #{script}"
  end
end

desc "Run tests"
task :default => :test
