# frozen_string_literal: true

require "vernier"
require "zlib"

module Awfy
  module Collectors
    # CPU/wall profile of the call in its own pass. Written as JSON by vernier,
    # then gzipped here so the file name is <artefacts>/<slug>.vernier.json.gz.
    class Vernier < Collector
      def self.key = "vernier"

      def self.heavy? = true

      def self.metrics(data) = data.slice("samples")

      def around(context)
        value = nil
        path = context.artefact_path("vernier.json.gz")
        json_path = path.delete_suffix(".gz")
        begin
          @result = ::Vernier.profile(out: json_path) { value = yield }
          Zlib::GzipWriter.open(path) { |gz| gz.write(File.binread(json_path)) }
          @path = path # only once the .gz file actually exists
          value
        ensure
          # ::Vernier.profile writes json_path even when the block raises; clean it up either
          # way (success or error) so a raising block leaves no uncompressed .json debris.
          File.delete(json_path) if File.exist?(json_path)
        end
      end

      def stop(_context)
        data = {"samples" => sample_count}
        # Not reported when #around never produced a .gz file (a test error before it did).
        data["path"] = @path if @path
        data
      end

      private

      def sample_count
        return @result.samples.size if @result.respond_to?(:samples)
        # Forward-compat: a possible future vernier version reporting per-thread sample arrays
        # instead of a flat #samples array; sum them the same way.
        return @result.threads.values.sum { Array(it[:samples]).size } if @result.respond_to?(:threads)

        nil
      end
    end
  end
end
