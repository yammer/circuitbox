namespace :circuits do
  task :stats => :environment do
    service = ENV['SERVICE']
    partition_key = ENV['PARTITION']

    if service.blank?
      raise "You must specify a SERVICE env variable, eg. `bundle exec rake circuits:stats SERVICE=yammer`"
    else
      pp Circuitbox::CircuitBreaker.new(service).stats(partition_key)
    end
  end
end