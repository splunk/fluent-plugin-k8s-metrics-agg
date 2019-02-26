require 'bundler'
Bundler::GemHelper.install_tasks

require 'rake/testtask'
require 'rake/clean'

CLEAN.concat FileList[
  'docker/*.gem',
  'pkg'
]

Rake::TestTask.new(:test) do |t|
  t.libs.push('lib', 'test')
  t.test_files = FileList['test/**/test_*.rb']
  t.verbose = true
  t.warning = true
end

task default: [:test]

namespace :docker do
  desc 'Build docker image'
  task :build, [:tag] => :build do |t, args|
    raise 'Argument `tag` was not provided.' unless args.tag

    cp Dir['pkg/fluent-plugin-k8s-metrics-agg-*.gem'], 'docker/'
    sh "docker build --no-cache -t splunk/fluent-plugin-k8s-metrics-agg:#{args.tag} ./docker"
  end
end
