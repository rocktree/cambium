module Cambium
  module CambiumHelper

    def not_found
      raise ActionController::RoutingError.new('Not Found')
    end

    def avatar(user, size = 100, klass = nil)
      gravatar_id = Digest::MD5.hexdigest(user.email.downcase)
      content_tag(:div, :class => "avatar-container #{klass}") do
        image_tag "http://gravatar.com/avatar/#{gravatar_id}.png?s=#{size}&d=mm",
          :class => 'avatar'
      end
    end

    def admin
      @admin ||= Cambium::AdminPresenter.new(self)
    end

    def admin_view
      @admin_view ||= admin.view(controller_name)
    end

    def admin_table
      @admin_table ||= admin_view.nil? ? nil : admin_view.table
    end

    def admin_form
      @admin_form ||= begin
        if action_name == 'new' || action_name == 'create'
          admin_view.form.new
        else
          admin_view.form.edit
        end
      end
    end

    def admin_routes
      @admin_routes ||= admin.routes(@object)
    end

    def admin_model
      @admin_model ||= begin
        admin_view.model.constantize
      rescue
        "Cambium::#{admin_view.model}".constantize
      end
    end

    def cambium_page_title(title)
      content_tag(:div, :id => 'title-bar') do
        o  = content_tag(:h2, title, :class => 'page-title')
        if is_index? && has_new_form?
          o += link_to(
            admin_view.form.new.title,
            cambium_route(:new),
            :class => 'button new'
          )
        end
        if is_index? && admin_view.export.present?
          o += link_to(
            admin_view.export.button || "Export #{admin_table.title}",
            "#{cambium_route(:index)}.csv",
            :class => 'button export'
          )
        end
        if is_edit? && can_delete?
          o += link_to(
            admin_view.form.buttons.delete,
            cambium_route(:delete, @object),
            :class => 'button delete',
            :method => :delete,
            :data => { :confirm => 'Are you sure?' }
          )
        end
        o.html_safe
      end
    end

    def cambium_table(collection, columns)
      obj_methods = []
      content_tag(:section, :class => 'data-table') do
        p = content_tag(:table) do
          o = content_tag(:thead) do
            content_tag(:tr) do
              o2 = ''
              columns.to_h.each do |col|
                obj_methods << (col.last.display_method || col.first.to_s)
                if col.last.sortable
                  o2 += content_tag(:th) do
                    path = "admin_#{controller_name}_path"
                    args = {
                      :page => params[:page] || 1,
                      :sort_by => col.first,
                      :order => (params[:order] == 'asc' &&
                                 params[:sort_by] == col.first) ? :desc : :asc
                    }
                    begin
                      route = cambium.send(path, args)
                    rescue
                      route = main_app.send(path, args)
                    end
                    klass  = args[:order].to_s
                    klass += ' active' if params[:sort_by] == col.first.to_s
                    link_to(col.last.heading, route, :class => klass)
                  end
                else
                  o2 += content_tag(:th, col.last.heading)
                end
              end
              o2 += content_tag(:th, nil)
              o2.html_safe
            end
          end
          o += content_tag(:tbody) do
            o2 = ''
            collection.each do |obj|
              o2 += content_tag(:tr) do
                o3 = ''
                obj_methods.each do |method|
                  o3 += content_tag(:td, obj.send(method))
                end
                o3 += content_tag(:td, link_to('', cambium_route(:edit, obj)),
                                  :class => 'actions')
                o3.html_safe
              end
            end
            o2.html_safe
          end
          o.html_safe
        end
        p += paginate(collection)
      end
    end

    def cambium_form(obj, fields, url=nil, &block)
      content_tag(:section, :class => 'form') do
        if url.nil?
          case action_name
          when 'edit', 'update'
            url = cambium_route(:show, obj)
          else
            url = cambium_route(:index, obj)
          end
        end
        simple_form_for obj, :url => url do |f|
          o  = cambium_form_fields(f, obj, fields)
          o += capture(f, &block) if block_given?
          o += f.submit
          o
        end
      end
    end

    def cambium_form_fields(f, obj, fields)
      o = ''
      fields.to_h.each do |field|
        o += cambium_field(f, obj, field)
      end
      o.html_safe
    end

    def cambium_field(f, obj, field)
      attr = field.first.to_s
      options = field.is_a?(OpenStruct) ? field : field.last
      options = options.to_ostruct unless options.class == OpenStruct
      readonly = options.readonly || false
      label = options.label || attr.titleize
      required = options.required || false
      if options.type == 'heading'
        content_tag(:h2, options.label || attr.titleize)
      elsif ['select','check_boxes','radio_buttons'].include?(options.type)
        parts = options.options.split('.')
        if parts.size > 1
          collection = parts[0].constantize.send(parts[1])
        else
          collection = options.options
        end
        f.input(attr.to_sym, :as => options.type, :collection => collection,
                :label => label, :readonly => readonly)
      elsif options.type == 'belongs_to'
        parent_name = options.options.singularize.classify.downcase
        f.association parent_name, label: label, readonly: readonly
      elsif ['date','time'].include?(options.type)
        if obj.send(attr).present?
          val = (options.type == 'date') ?
            obj.send(attr).strftime("%d %B, %Y") :
            obj.send(attr).strftime("%l:%M %p")
        end
        f.input(attr.to_sym, :as => :string, :label => label,
                :input_html => {
                  :class => "picka#{options.type}",
                  :value => val.nil? ? nil : val
                }, :readonly => readonly)
      elsif options.type == 'datetime'
        content_tag(:div, :class => 'input string pickadatetime') do
          o2 = content_tag(:label, label)
          o2 += content_tag(:input, '', :label => label, :placeholder => 'Date',
                            :type => 'text', :class => 'pickadatetime-date',
                            :value => obj.send(attr).present? ?
                              obj.send(attr).strftime("%d %B, %Y") : '',
                            :readonly => readonly)
          o2 += content_tag(:input, '', :label => label, :placeholder => 'Time',
                            :type => 'text', :class => 'pickadatetime-time',
                            :value => obj.send(attr).present? ?
                              obj.send(attr).strftime("%l:%M %p") : '',
                            :readonly => readonly)
          o2 += f.input(attr.to_sym, :as => :hidden, :wrapper => false,
                        :label => false,
                        :input_html => { :class => 'pickadatetime' })
        end
      elsif options.type == 'markdown'
        content_tag(:div, :class => "input text optional #{attr}") do
          o2  = content_tag(:label, label, :for => attr)
          o2 += content_tag(:div, f.markdown(attr.to_sym), :class => 'markdown')
        end
      elsif options.type == 'wysiwyg'
        f.input(attr.to_sym, :as => :text, :label => label,
                :input_html => { :class => 'editor' }, :required => required)
      elsif options.type == 'media'
        content_tag(:div, :class => 'input media-picker file') do
          o2  = content_tag(:label, label)
          o2 += link_to('Choose File', '#', :class => 'add')
          o2 += link_to('Remove File', '#',
            :class => "remove #{'active' unless obj.send(attr).blank? }")
          unless obj.send(attr).blank?
            ext = obj.send(attr).upload.ext.downcase
            if ['jpg','jpeg','gif','png'].include?(ext)
              o2 += image_tag(obj.send(attr).image_url(400, 400))
            end
            o2 += link_to(obj.send(attr).upload.name,
                          obj.send(attr).upload.url,
                         :class => 'file', :target => :blank)
          end
          o2 += f.input(attr.to_sym, :as => :hidden, :wrapper => false)
        end
      elsif options.type == 'file'
        o = f.input(attr.to_sym, :as => options.type, :label => label,
                :readonly => readonly, :required => required)
        unless obj.send(attr).blank?
          # Dragonfly ...
          if obj.send(attr).respond_to?(:ext)
            if %w(jpg jpeg gif png).include?(obj.send(attr).ext.downcase)
              o += image_tag obj.send(attr)
                                .thumb("200x200##{obj.send("#{attr}_gravity")}")
                                .url
              o += content_tag(:div, :class => 'image-actions') do
                o2  = ''.html_safe
                o2 += link_to('Crop Image', '#', :class => 'crop',
                              :target => :blank, :data => {
                              :url => obj.send(attr).url,
                              :width => obj.send(attr).width,
                              :height => obj.send(attr).height }) if options.crop
                o2 += link_to(obj.send(attr).name, obj.send(attr).url,
                         :class => 'file', :target => :blank)
                o2 += f.input :"#{attr}_gravity", :as => :hidden
              end
            else
              o += link_to(obj.send(attr).name, obj.send(attr).url,
                           :class => 'file', :target => :blank)
            end
          # CarrierWave (assumed, for now)
          else
            if %w(jpg jpeg gif png).include?(obj.send(attr).file.extension.downcase)
              o += image_tag obj.send(attr).thumb.url
              o += content_tag(:div, :class => 'image-actions') do
                o2  = ''.html_safe
                # o2 += link_to('Crop Image', '#', :class => 'crop',
                #               :target => :blank, :data => {
                #               :url => obj.send(attr).url,
                #               :width => obj.send(attr).width,
                #               :height => obj.send(attr).height }) if options.crop
                o2 += link_to(obj.send(attr).file.filename, obj.send(attr).url,
                         :class => 'file', :target => :blank)
                # o2 += f.input :"#{attr}_gravity", :as => :hidden
              end
            else
              o += link_to(obj.send(attr).name, obj.send(attr).url,
                           :class => 'file', :target => :blank)
            end
          end
        end
        o
      else
        f.input(attr.to_sym, :as => options.type, :label => label,
                :readonly => readonly, :required => required)
      end
    end

    def cambium_route(action, obj = nil)
      c_name = controller_name.singularize
      case action
      when :index
        begin
          main_app
            .polymorphic_path [:admin, controller_name.to_sym]
        rescue
          cambium.polymorphic_path [:admin, controller_name.to_sym]
        end
      when :edit
        begin
          main_app.polymorphic_path [:edit, :admin, obj]
        rescue
          cambium.polymorphic_path [:edit, :admin, obj]
        end
      when :new
        begin
          main_app.polymorphic_path [:new, :admin, c_name.to_sym]
        rescue
          cambium.polymorphic_path [:new, :admin, c_name.to_sym]
        end
      else
        begin
          main_app.polymorphic_path [:admin, obj]
        rescue
          cambium.polymorphic_path [:admin, obj]
        end
      end
    end

    def is_index?
      action_name == 'index'
    end

    def is_edit?
      ['edit','update'].include?(action_name)
    end

    def has_new_form?
      admin_view.form.present? && admin_view.form.new.present?
    end

    def can_delete?
      admin_view.form.present? && admin_view.form.buttons.present? &&
        admin_view.form.buttons.delete.present?
    end

  end
end
