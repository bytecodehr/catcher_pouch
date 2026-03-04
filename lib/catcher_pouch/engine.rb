# frozen_string_literal: true

module CatcherPouch
  class Engine < ::Rails::Engine
    isolate_namespace CatcherPouch

    initializer 'catcher_pouch.assets' do |app|
      # No asset pipeline needed — we use CDN for CodeMirror
    end
  end
end
