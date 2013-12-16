require 'rails/application_controller'

class Rails::MailersController < Rails::ApplicationController # :nodoc:
  prepend_view_path ActionDispatch::DebugExceptions::RESCUES_TEMPLATE_PATH

  before_filter :require_local!
  before_filter :find_preview, only: :preview

  def index
    @previews = ActionMailer::Preview.all
    @page_title = "Mailer Previews"
  end

  def preview
    if params[:path] == @preview.preview_name
      @page_title = "Mailer Previews for #{@preview.preview_name}"
      render action: 'mailer'
    else
      email = File.basename(params[:path])

      if @preview.email_exists?(email)
        @email = @preview.call(email)

        if params[:part]
          part_type = Mime::Type.lookup(params[:part])

          if part = find_part(part_type)
            response.content_type = part_type
            render text: part.respond_to?(:decoded) ? part.decoded : part
          else
            render text: "<p>Email part: '#{part_type}' not found</p>", status: :not_found
          end
        else
          @part = find_preferred_part(request.format, Mime::HTML, Mime::TEXT)
          render action: 'email', layout: false
        end
      else
        render text: "<p>Email '#{email}' not found in preview '#{@preview.preview_name}'</p>", status: :not_found
      end
    end
  end

  protected
    def find_preview
      candidates = []
      params[:path].to_s.scan(%r{/|$}){ candidates << $` }
      preview = candidates.detect{ |candidate| ActionMailer::Preview.exists?(candidate) }

      if preview
        @preview = ActionMailer::Preview.find(preview)
      else
        render text: '<p>Mailer preview not found.</p>', status: :not_found
      end
    end

    def find_preferred_part(*formats)
      if @email.multipart?
        formats.each do |format|
          return find_part(format) if @email.parts.any?{ |p| p.mime_type == format }
        end
      else
        @email
      end
    end

    def find_part(format)
      if @email.multipart?
        @email.parts.find{ |p| p.mime_type == format }
      else
        @email
      end
    end
end