# frozen_string_literal: true

raise "JWT_SECRET environment variable must be set" unless ENV["JWT_SECRET"].present?
