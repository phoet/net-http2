module NetHttp2

  class Stream

    def initialize(options={})
      @h2_stream = options[:h2_stream]
      @headers   = {}
      @data      = ''
      @request   = nil
      @completed = false
      @async     = false

      listen_for_headers
      listen_for_data
      listen_for_close
    end

    def call_with(request)
      @request = request
      send_request_data
      sync_respond
    end

    def async_call_with(request)
      @request = request
      @async   = true
      send_request_data
    end

    def completed?
      @completed
    end

    def async?
      @async
    end

    private

    def listen_for_headers
      @h2_stream.on(:headers) do |hs_array|
        hs = Hash[*hs_array.flatten]

        if async?
          @request.emit(:headers, hs)
        else
          @headers.merge!(hs)
        end
      end
    end

    def listen_for_data
      @h2_stream.on(:data) do |data|
        if async?
          @request.emit(:body_chunk, data)
        else
          @data << data
        end
      end
    end

    def listen_for_close
      @h2_stream.on(:close) do |data|
        @completed = true

        @request.emit(:close, data) if async?
      end
    end

    def send_request_data
      headers = @request.headers
      body    = @request.body
      if body
        puts "-----> SENDING HEADERS\r\n"
        @h2_stream.headers(headers, end_stream: false)

        sleep 1
        puts "\r\n-----> SENDING BODY\r\n"
        @h2_stream.data(body, end_stream: true)
        puts "SEND DONE"
      else
        @h2_stream.headers(headers, end_stream: true)
      end
    end

    def sync_respond
      wait_for_completed

      NetHttp2::Response.new(headers: @headers, body: @data) if @completed
    end

    def wait_for_completed
      cutoff_time = Time.now + @request.timeout

      while !@completed && Time.now < cutoff_time
        sleep 0.1
      end
    end
  end
end
