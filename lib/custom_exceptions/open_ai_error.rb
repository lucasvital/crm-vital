# frozen_string_literal: true

class CustomExceptions::OpenAiError < CustomExceptions::Base
  def http_status
    422
  end
end

