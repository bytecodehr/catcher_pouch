# frozen_string_literal: true

module CatcherPouch
  class MailersController < ApplicationController
    def index
      @mailers = MailerDiscovery.discover
    end

    def show
      mailer_class_name = params[:mailer_class]
      @mailer = MailerDiscovery.discover.find { |m| m[:mailer_class] == mailer_class_name }

      return if @mailer

      redirect_to root_path, alert: "Mailer '#{mailer_class_name}' not found"
    end
  end
end
