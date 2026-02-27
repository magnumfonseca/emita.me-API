# frozen_string_literal: true

class Result
  attr_reader :data, :error

  def self.success(data)
    new(success: true, data: data)
  end

  def self.failure(error)
    new(success: false, error: error)
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  private

  def initialize(success:, data: nil, error: nil)
    @success = success
    @data    = data
    @error   = error
  end
end
