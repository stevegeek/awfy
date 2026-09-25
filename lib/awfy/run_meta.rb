# frozen_string_literal: true

module Awfy
  # Facts about the measuring process: the run document's "meta", also saved with each result.
  # Awfy::Rails.boot! merges in the Rails facts.
  module RunMeta
    class << self
      def merge!(hash)
        data.merge!(hash.transform_keys(&:to_s))
      end

      def snapshot
        {
          "ruby" => RUBY_DESCRIPTION,
          "yjit" => RubyVM.const_defined?(:YJIT) && RubyVM::YJIT.enabled?,
          "pid" => Process.pid
        }.merge(data)
      end

      def reset!
        @data = {}
      end

      private

      def data
        @data ||= {}
      end
    end
  end
end
