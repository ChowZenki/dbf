module DBF
  class ColumnLengthError < StandardError; end
  class ColumnNameError < StandardError; end

  # DBF::Column stores all the information about a column including its name,
  # type, length and number of decimal places (if any)
  class Column
    attr_reader :name, :type, :length, :decimal

    # Initialize a new DBF::Column
    #
    # @param [String] name
    # @param [String] type
    # @param [Fixnum] length
    # @param [Fixnum] decimal
    def initialize(name, type, length, decimal, encoding=nil)
      @name, @type, @length, @decimal, @encoding = clean(name), type, length, decimal, encoding

      raise ColumnLengthError, "field length must be greater than 0" unless length > 0
      raise ColumnNameError, "column name cannot be empty" if @name.length == 0
    end

    # Cast value to native type
    #
    # @param [String] value
    # @return [Fixnum, Float, Date, DateTime, Boolean, String]
    def type_cast(value)
      case type
        when 'N' then unpack_number(value)
        when 'I' then unpack_unsigned_long(value)
        when 'F' then value.to_f
        when 'D' then decode_date(value)
        when 'T' then decode_datetime(value)
        when 'L' then boolean(value)
        when 'B' then unpack_binary(value)
        else          encode_string(value.to_s).strip
      end
    end

    def memo?
      @memo ||= type == 'M'
    end

    # Schema definition
    #
    # @return [String]
    def schema_definition
      "\"#{underscored_name}\", #{schema_data_type}\n"
    end

    def underscored_name
      @underscored_name ||= Util.underscore(name)
    end

    private

    def decode_date(value) #nodoc
      value.gsub!(' ', '0')
      value !~ /\S/ ? nil : Date.parse(value)
    rescue
      nil
    end

    def decode_datetime(value) #nodoc
      days, milliseconds = value.unpack('l2')
      seconds = milliseconds / 1000
      DateTime.jd(days, seconds/3600, seconds/60 % 60, seconds % 60) rescue nil
    end

    def unpack_number(value) #nodoc
      decimal.zero? ? value.to_i : value.to_f
    end

    def unpack_unsigned_long(value) #nodoc
      value.unpack('V')[0]
    end
    
    def unpack_binary(value) #nodoc
    end

    def boolean(value) #nodoc
      value.strip =~ /^(y|t)$/i ? true : false
    end

    def encode_string(value)
      @encoding ? value.force_encoding(@encoding).encode(Encoding.default_external, :undef => :replace, :invalid => :replace) : value
    end

    def schema_data_type #nodoc
      case type
      when "N", "F"
        decimal > 0 ? ":float" : ":integer"
      when "I"
        ":integer"
      when "D"
        ":date"
      when "T"
        ":datetime"
      when "L"
        ":boolean"
      when "M"
        ":text"
      else
        ":string, :limit => #{length}"
      end
    end

    def clean(s) #nodoc
      first_null = s.index("\x00")
      s = s[0, first_null] if first_null
      s.gsub(/[^\x20-\x7E]/, "")
    end

  end

end
