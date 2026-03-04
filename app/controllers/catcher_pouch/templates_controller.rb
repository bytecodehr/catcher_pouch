# frozen_string_literal: true

module CatcherPouch
  class TemplatesController < ApplicationController
    before_action :set_template, only: %i[show preview update]

    def show
      @content = File.read(@template[:path])
      @preview = TemplateRenderer.render_preview(@template[:mailer_class], @template[:action])
    end

    def preview
      result = TemplateRenderer.render_preview(@template[:mailer_class], @template[:action])

      if result[:error]
        render plain: <<~HTML, content_type: 'text/html'
          <div style="font-family: monospace; padding: 20px; color: #dc2626; background: #fef2f2; border: 1px solid #fecaca; border-radius: 8px; margin: 20px;">
            <strong>Preview Error</strong><br><br>
            <pre style="white-space: pre-wrap;">#{ERB::Util.html_escape(result[:error])}</pre>
          </div>
        HTML
      elsif result[:html]
        render html: result[:html].html_safe
      else
        render plain: result[:text] || 'No preview available'
      end
    end

    def update
      unless CatcherPouch.config.editable
        redirect_to templates_show_path(path: params[:path]), alert: 'Editing is disabled in this environment'
        return
      end

      content = params[:content]

      # Validate ERB syntax before saving
      validation = TemplateRenderer.validate_erb(content)
      unless validation[:valid]
        @content = content
        @template = find_template
        @preview = TemplateRenderer.render_preview(@template[:mailer_class], @template[:action])
        @error = validation[:error]
        render :show, status: :unprocessable_entity
        return
      end

      File.write(@template[:path], content)
      redirect_to templates_show_path(path: params[:path]), notice: 'Template saved successfully'
    end

    private

    def set_template
      @template = find_template
      return if @template

      redirect_to root_path, alert: 'Template not found'
    end

    def find_template
      MailerDiscovery.find_template(params[:path])
    end
  end
end
