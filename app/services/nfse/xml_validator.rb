# frozen_string_literal: true

module Nfse
  class XmlValidator
    SCHEMAS_PATH = Pathname.new(ENV.fetch("NFSE_SCHEMAS_PATH", ".docs/references/schemas"))

    def validate_dps!(xml_string)
      validate!(xml_string, schema_for("DPS_v1.01.xsd"))
    end

    def validate_nfse!(xml_string)
      validate!(xml_string, schema_for("NFSe_v1.01.xsd"))
    end

    private

    def validate!(xml_string, schema)
      doc    = Nokogiri::XML(xml_string)
      errors = schema.validate(doc)
      raise Errors::ValidationError, errors.map(&:message).join(", ") unless errors.empty?
    end

    def schema_for(filename)
      schema_path = SCHEMAS_PATH.join(filename)
      Nokogiri::XML::Schema(File.open(schema_path))
    end
  end
end
