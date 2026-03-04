# frozen_string_literal: true

module CatcherPouch
  class TemplateRenderer
    # Renders a preview for a given mailer class and action.
    # Returns { html: String, text: String, subject: String, from: String, to: String, error: String|nil }
    def self.render_preview(mailer_class_name, action)
      config = CatcherPouch.config
      preview_proc = config.previews.dig(mailer_class_name, action)

      unless preview_proc
        return {
          html: nil,
          text: nil,
          subject: nil,
          error: "No preview configured for #{mailer_class_name}##{action}. " \
                 'Add it to CatcherPouch.configure { |c| c.previews = { ... } }'
        }
      end

      begin
        mail = preview_proc.call

        # If it's a Mail::Message, extract parts
        if mail.is_a?(Mail::Message)
          html_part = mail.html_part&.body&.decoded || (mail.content_type&.include?('text/html') ? mail.body.decoded : nil)
          text_part = mail.text_part&.body&.decoded || (mail.content_type&.include?('text/plain') ? mail.body.decoded : nil)

          {
            html: html_part,
            text: text_part,
            subject: mail.subject,
            from: Array(mail.from).join(', '),
            to: Array(mail.to).join(', '),
            error: nil
          }
        elsif mail.respond_to?(:message)
          # ActionMailer::MessageDelivery
          message = mail.message
          html_part = message.html_part&.body&.decoded || (message.content_type&.include?('text/html') ? message.body.decoded : nil)
          text_part = message.text_part&.body&.decoded || (message.content_type&.include?('text/plain') ? message.body.decoded : nil)

          {
            html: html_part,
            text: text_part,
            subject: message.subject,
            from: Array(message.from).join(', '),
            to: Array(message.to).join(', '),
            error: nil
          }
        else
          { html: nil, text: nil, subject: nil, error: 'Preview proc did not return a Mail::Message' }
        end
      rescue StandardError => e
        {
          html: nil,
          text: nil,
          subject: nil,
          error: "#{e.class}: #{e.message}\n\n#{e.backtrace&.first(10)&.join("\n")}"
        }
      end
    end

    # Renders raw ERB content with an empty binding for syntax checking.
    def self.validate_erb(content)
      ERB.new(content)
      { valid: true, error: nil }
    rescue SyntaxError => e
      { valid: false, error: e.message }
    end
  end
end
