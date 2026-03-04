# frozen_string_literal: true

require 'catcher_pouch/engine'
require 'catcher_pouch/configuration'
require 'catcher_pouch/mailer_discovery'
require 'catcher_pouch/template_renderer'

module CatcherPouch
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def config
      configuration || configure
    end
  end
end
