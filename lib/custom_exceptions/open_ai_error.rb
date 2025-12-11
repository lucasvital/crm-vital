# frozen_string_literal: true

class CustomExceptions::OpenAIError < CustomExceptions::Base
  def http_status
    422
  end
end

