module Cambium
  class Document < ActiveRecord::Base

    extend Dragonfly::Model

    # ------------------------------------------ Plugins

    include PgSearch

    multisearchable :against => [:title]
    has_paper_trail

    dragonfly_accessor :upload

    # ------------------------------------------ Scopes

    scope :last_created, -> { order(:created_at => :desc) }

    # ------------------------------------------ Validations

    validates :title, :upload, :presence => true

    # ------------------------------------------ Instance Methods

    def to_s
      title
    end

    def image?
      ['jpg','jpeg','gif','png'].include?(upload.ext.downcase)
    end

    def pdf?
      upload.ext.downcase == 'pdf'
    end

    def has_thumb?
      thumb_url.present?
    end

    def thumb_url
      return image_url(300, 300)
      return png_cover_image_url(300, 300) if pdf?
      nil
    end

    def image_url(width, height)
      upload.thumb("#{width}x#{height}##{upload_gravity}").url
    end

    def png_cover_image_url(width, height)
      upload.thumb("#{width}x#{height}##{upload_gravity}", :format => 'png',
                   :frame => 0).url
    end

    def ext
      upload.ext
    end

  end
end
