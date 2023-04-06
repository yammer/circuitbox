# frozen_string_literal: true

class Circuitbox
  module TimeHelper
    module Real
      module_function

      def current_second
        ::Time.now.to_i
      end
    end
  end
end
