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

      mailers.sort_by(&:name).filter_map do |mailer_class|
        actions = mailer_actions(mailer_class)
        templates = actions.flat_map { |action| templates_for(mailer_class, action) }

        # Only include mailers that have at least one app-level template
        next if templates.empty?

        # Filter actions to only those with app-level templates
        actions_with_templates = templates.map { |t| t[:action] }.uniq
        {
          mailer_class: mailer_class.name,
          actions: actions_with_templates.sort,
          templates: templates
        }
      end
    end

    # Returns all template files for a specific mailer and action.
    # Only returns app-level templates (from app/views). Gem-bundled templates
    # that haven't been overridden are excluded — they can't be meaningfully
    # edited and often reference helpers/routes that may not exist.
    def self.templates_for(mailer_class, action)
      app_views = Rails.root.join('app/views').to_s
      prefix = mailer_class.name.underscore
      dir = File.join(app_views, prefix)
      return [] unless File.directory?(dir)

      templates = []
      Dir.glob(File.join(dir, "#{action}*")).each do |file|
        next if File.directory?(file)

        templates << {
          mailer_class: mailer_class.name,
          action: action,
          path: file,
          relative_path: file.sub("#{app_views}/", ''),
          format: detect_format(file),
          filename: File.basename(file),
          app_template: true
        }
      end

      templates
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

    # Discover actions from app-level template files only.
    # This catches inherited actions (e.g. invitation_instructions from DeviseInvitable)
    # that have been overridden in the app, while ignoring gem-only templates.
    def self.actions_from_templates(mailer_class)
      app_views = Rails.root.join('app/views').to_s
      prefix = mailer_class.name.underscore
      dir = File.join(app_views, prefix)
      return [] unless File.directory?(dir)

      actions = []
      Dir.glob(File.join(dir, '*')).each do |file|
        next if File.directory?(file)

        basename = File.basename(file)
        action = basename.sub(/\.(html|text)\.(erb|haml|slim)$/, '').sub(/\.(erb|haml|slim)$/, '')
        actions << action
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
