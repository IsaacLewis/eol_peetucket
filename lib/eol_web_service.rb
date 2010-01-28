require 'net/http'
require 'uri'
require 'socket'

# Be careful not to use this class in tests!
# It makes real network connections!
# Will *not* work offline.
class EOLWebService
   
# confirm the passed in URL is valid and responses with a proper code
  def self.valid_url?(url)
    valid_url = true
    return true if RAILS_ENV == 'test' # JRice needed this 'cause he was working off the network!
    begin
      parsed_url=URI.parse(url)
      header=Net::HTTP.new(parsed_url.host,parsed_url.port).head(parsed_url.path == '' ? '/' : parsed_url.path)    
      valid_url = false unless ['200','301','302'].include?(header.code) 
    rescue
      valid_url = false
    end
    valid_url
  end
  
  #finds local ip used by the host for remote connection
  def self.local_ip
    begin
      return nil if RAILS_ENV == 'test'
      orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

      UDPSocket.open do |s|
        s.connect '64.233.187.99', 1   # this is Google's IP address
        s.addr.last
      end
    rescue Errno::ENETUNREACH
      # do nothing, the network is unreachable
    end

    ensure
      Socket.do_not_reverse_lookup = orig
  end
   
 # calls the webservice with the supplied querystring parameters and returns the XML response if the call was successful, otherwise returns NIL
  def self.call(params)
   
   resp="" 
   base_url=params[:base_url] || $WEB_SERVICE_BASE_URL
   timeout_seconds=params[:timeout_seconds] || $WEB_SERVICE_TIMEOUT_SECONDS 
   parameters=params[:parameters] || ""
   if $LOG_WEB_SERVICE_EXECUTION_TIME
     elapsedSeconds = Benchmark::realtime do
      resp=self.web_service_call(params) 
     end
     logging_message='*** WEB SERVICE CALL (' + elapsedSeconds.to_s + 's'
     logging_message+=' TIMED OUT AFTER ' + timeout_seconds.to_s + ' s' if elapsedSeconds.to_f >= timeout_seconds.to_f
     logging_message+='): ' + base_url + parameters
     RAILS_DEFAULT_LOGGER.info logging_message
   else
     resp=self.web_service_call(params)
   end
   
   if resp.nil? == false && resp.code == "200"
        return resp.body
   else
        return nil
   end  
      
  end

  # make the actual call to the web service
  def self.web_service_call(params)
    
     base_url=params[:base_url] || $WEB_SERVICE_BASE_URL
     parameters=params[:parameters] || ""
     timeout_seconds=params[:timeout_seconds] || $WEB_SERVICE_TIMEOUT_SECONDS    
       
     begin
         return Timeout::timeout(timeout_seconds) {resp=Net::HTTP.get_response(URI.parse(base_url + parameters))}
     rescue TimeoutError 
         if $ERROR_LOGGING
            ErrorLog.create(
              :url=>base_url,
              :exception_name=>"web service timed out",
              :backtrace=>parameters
              ) 
          end         
         return nil
     end
     
  end
  
  # takes one or several parameters to delete from a url
  def self.uri_remove_param(uri, params = nil)
    return uri unless params
    params = [params] if params.class == String
    uri_parsed = URI.parse(uri)
    return uri unless uri_parsed.query
    escaped = uri_parsed.query.grep(/&amp;/).size > 0
    new_params = uri_parsed.query.gsub(/&amp;/, '&').split('&').reject { |q| params.include?(q.split('=').first) }
    uri = uri.split('?').first
    amp = escaped ? '&amp;' : '&'
    params = new_params.join(amp)
    params.blank? ? uri : "#{uri}?#{params}"
  end
 
end
  
