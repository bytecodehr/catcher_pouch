# frozen_string_literal: true

module CatcherPouch
  class ApplicationController < ::ActionController::Base
    before_action :authorize_access!

    layout -> { CatcherPouch.config.layout || 'catcher_pouch/application' }

    private

    def authorize_access!
      auth = CatcherPouch.config.authorization
      return if auth.nil?
      return if auth.call(self)

      render plain: 'Not authorized', status: :forbidden
    end
  end
end
