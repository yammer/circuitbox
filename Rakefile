require "rake/testtask"
require "bundler/gem_version_tasks"

namespace :test do
  desc "Run complete test suite"
  task :all => [:unit, :integration]

  desc "Run unit tests"
  Rake::TestTask.new(:unit) do |t|
    t.libs << "test"
    t.test_files = FileList["test/*_test.rb"]
  end

  desc "Run integration tests"
  Rake::TestTask.new(:integration) do |t|
    t.libs << "test"
    t.test_files = FileList["test/integration/*_test.rb"]
  end

  desc "Run the circuitbox benchmarks"
  task :benchmark do
    benchmark_scripts = FileList.new("./benchmark/*_benchmark.rb")
    benchmark_scripts.each do |script|
      system "bundle exec ruby #{script}"
    end
  end
end

desc "Run tests"
task :default => ["test:all"]
