# frozen_string_literal: true

class ApiConnector
  require 'faraday'
  require 'faraday/net_http'
  Faraday.default_adapter = :net_http

  attr_reader :auth_token

  def initialize(username:, password: nil, token: nil, **_other_options)
    @auth_token = token || generate_token(username: username, password: password)
  end

  def self.call(**args)
    new(**args).call_action
  end

  def call_action(**args)
    __send__(self.class::ACTION, **args)
  end

  private

  def request(url:, method:, params: nil, headers: nil)
    request = faraday_request(url: url, headers: headers)
    response = if %w[get].include? method
                 request.send(method, url, params)
               else
                 request.send(method) do |req|
                   req.headers['Content-Type'] = 'application/json'
                   req.body = params.to_json
                 end
               end
    success = response.status == 200
    case response['content-type']
    when 'application/pdf'
      body = { data: response.body, message: response.headers['content-disposition'] }
    when %r{application/json}
      body = JSON.parse(response.body).with_indifferent_access
    else
      raise Faraday::Error, 'Unsupported content type'
    end
    OpenStruct.new(body: body,
                   success: success,
                   type: response['content-type'])
  rescue Faraday::Error => e
    OpenStruct.new(body: { code: 503, message: e.message,
                           data: {} }, success: false)
  end

  def generate_token(username:, password:)
    Base64.urlsafe_encode64("#{username}:#{password}")
  end

  def base_url
    "#{ENV['REPP_HOST']}#{ENV['REPP_ENDPOINT']}"
  end

  def faraday_request(url:, headers: {})
    Faraday.new(
      url: url,
      headers: headers.present? ? base_headers.merge!(headers) : base_headers,
      ssl: ca_auth_params
    )
  end

  def ca_auth_params
    return if Rails.env.test?

    client_cert = File.read(ENV['cert_path'])
    client_key = File.read(ENV['key_path'])
    {
      client_cert: OpenSSL::X509::Certificate.new(client_cert),
      client_key: OpenSSL::PKey::RSA.new(client_key),
    }
  end

  def base_headers
    { 'Authorization' => "Basic #{@auth_token}" }
  end

  def endpoint_url
    base_url + self.class::ENDPOINT[:endpoint]
  end

  def method
    self.class::ENDPOINT[:method]
  end

  def url_with_id(id)
    "#{endpoint_url}/#{id}"
  end

end
