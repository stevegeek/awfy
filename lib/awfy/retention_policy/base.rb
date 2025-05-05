# frozen_string_literal: true

module Awfy
  module RetentionPolicy
    # Base abstract class for retention policies
    #
    # Retention policies determine which benchmark results are kept in storage
    # and which ones can be cleaned up. Each policy implementation must define
    # the `retain?` method that takes a result and returns true or false.
    class Base
      def initialize(options)
        @options = options
      end

      def retain?(result)
        raise NotImplementedError, "#{self.class} must implement the retain? method"
      end

      def name
        self.class.name.split("::").last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end
    end
  end
end
