# frozen_string_literal: true

module Nfse
  class XmlCompressor
    def compress(xml_string)
      Base64.strict_encode64(gzip(xml_string))
    end

    def decompress(base64_string)
      gzipped = Base64.strict_decode64(base64_string)
      Zlib::GzipReader.new(StringIO.new(gzipped)).read
    end

    private

    def gzip(data)
      output = StringIO.new
      gz     = Zlib::GzipWriter.new(output)
      gz.write(data)
      gz.close
      output.string
    end
  end
end
