require 'circuitbox'
require 'rails'

class Circuitbox
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/circuits.rake"
    end
  end
end