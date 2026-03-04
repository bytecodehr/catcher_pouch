# frozen_string_literal: true

module CatcherPouch
  class MailerDiscovery
    # Returns an array of hashes representing all discovered mailers and their actions.
    # Each hash: { mailer_class: String, actions: [String], templates: [Hash] }
    def self.discover
      eager_load_mailers!

      mailers = ActionMailer::Base.descendants.reject do |klass|
        klass == ActionMailer::Base || klass.name == 'ApplicationMailer' || klass.name&.start_with?('ActionMailer::')
      end

      mailers.sort_by(&:name).map do |mailer_class|
        actions = mailer_actions(mailer_class)
        {
          mailer_class: mailer_class.name,
          actions: actions,
          templates: actions.flat_map { |action| templates_for(mailer_class, action) }
        }
      end
    end

    # Returns all template files for a specific mailer and action.
    # When an app-level template exists, gem-bundled defaults are excluded.
    def self.templates_for(mailer_class, action)
      view_paths = resolve_view_paths(mailer_class)
      app_views = Rails.root.join('app/views').to_s
      templates = []

      view_paths.each do |base_path|
        prefix = mailer_class.name.underscore
        dir = File.join(base_path, prefix)
        next unless File.directory?(dir)

        Dir.glob(File.join(dir, "#{action}*")).each do |file|
          next if File.directory?(file)

          relative = file.sub("#{base_path}/", '')
          format = detect_format(file)
          app_template = file.start_with?(app_views)

          templates << {
            mailer_class: mailer_class.name,
            action: action,
            path: file,
            relative_path: relative,
            format: format,
            filename: File.basename(file),
            app_template: app_template
          }
        end
      end

      # Deduplicate: prefer app-level templates over gem-bundled ones
      templates.uniq { |t| t[:relative_path] }.select do |t|
        # Keep if it's an app template, or if no app template exists for this relative path
        t[:app_template] || templates.none? do |other|
          other[:relative_path] == t[:relative_path] && other[:app_template]
        end
      end
    end

    # Returns all discoverable template files across all mailers.
    def self.all_templates
      discover.flat_map { |m| m[:templates] }.uniq { |t| t[:path] }
    end

    # Find a specific template by its relative path.
    def self.find_template(relative_path)
      all_templates.find { |t| t[:relative_path] == relative_path }
    end

    def self.eager_load_mailers!
      mailer_dir = Rails.root.join('app/mailers')
      return unless mailer_dir.exist?

      # Prefer Zeitwerk eager loading (Rails 7+)
      if defined?(Zeitwerk) && Rails.autoloaders.main.respond_to?(:eager_load_dir)
        Rails.autoloaders.main.eager_load_dir(mailer_dir)
      else
        Dir.glob(mailer_dir.join('**', '*.rb')).each do |file|
          require_dependency file
        end
      end
    end

    def self.mailer_actions(mailer_class)
      # Get public instance methods defined directly on this mailer (not inherited from Base)
      method_actions = mailer_class.instance_methods(false)
                                   .select { |m| mailer_class.instance_method(m).arity <= 0 || mailer_class.instance_method(m).arity >= -2 }
                                   .map(&:to_s)
                                   .reject { |m| m.start_with?('_') }

      # Also discover actions from template files (catches inherited actions like invitation_instructions)
      template_actions = actions_from_templates(mailer_class)

      (method_actions + template_actions).uniq.sort
    rescue StandardError => e
      Rails.logger.warn "[CatcherPouch] Could not discover actions for #{mailer_class}: #{e.message}"
      []
    end

    def self.actions_from_templates(mailer_class)
      view_paths = resolve_view_paths(mailer_class)
      prefix = mailer_class.name.underscore
      actions = []

      view_paths.each do |base_path|
        dir = File.join(base_path, prefix)
        next unless File.directory?(dir)

        Dir.glob(File.join(dir, '*')).each do |file|
          next if File.directory?(file)

          # Extract action name: "confirmation_code.html.erb" -> "confirmation_code"
          basename = File.basename(file)
          action = basename.sub(/\.(html|text)\.(erb|haml|slim)$/, '').sub(/\.(erb|haml|slim)$/, '')
          actions << action
        end
      end

      actions.uniq
    end

    def self.resolve_view_paths(mailer_class)
      paths = []

      # Standard Rails view path
      paths << Rails.root.join('app/views').to_s

      # Any additional view paths from the mailer
      if mailer_class.respond_to?(:_view_paths)
        mailer_class._view_paths.each do |resolver|
          paths << resolver.path.to_s if resolver.respond_to?(:path) && resolver.path.present?
        end
      end

      paths.uniq
    end

    def self.detect_format(file)
      case File.extname(file.sub(/\.erb$/, ''))
      when '.html' then :html
      when '.text' then :text
      else :unknown
      end
    end
  end
end
