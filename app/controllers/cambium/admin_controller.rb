class Cambium::AdminController < Cambium::BaseController

  before_filter :authenticate_admin!

  before_filter :set_paper_trail_whodunnit
  before_filter :set_activities

  layout "admin"

  include Cambium::CambiumHelper

  def index
    respond_to do |format|
      scope = admin_table.scope
      if params[:sort_by]
        @collection = admin_model.unscoped
          .order("#{params[:sort_by]} #{params[:order] || 'asc'}")
      else
        if scope.split('.').size > 1
          @collection = admin_model
          scope.split('.').each do |s|
            @collection = @collection.send(s)
          end
        else
          @collection = admin_model.send(admin_table.scope)
        end
      end
      format.html do
        @collection = @collection.page(params[:page] || 1).per(15)
        render :layout => false if params[:no_layout]
      end
      format.csv do
        send_data admin.to_csv(@collection)
      end
    end
  end

  def show
    set_object
    redirect_to(admin_routes.edit)
  end

  def new
    @object = admin_model.new
  end

  def create
    @object = admin_model.new
    @object.update(create_params)
    if @object.save
      redirect_to(
        admin_routes.index,
        :notice => "#{admin_model.to_s.gsub(/Cambium::/, '')} created!")
    else
      render 'new'
    end
  end

  def edit
    set_object
  end

  def update
    set_object
    if @object.update(update_params)
      redirect_to(
        admin_routes.index,
        :notice => "#{admin_model.to_s.gsub(/Cambium::/, '')} updated!")
    else
      render 'edit'
    end
  end

  def destroy
    set_object
    @object.destroy
    redirect_to(
      admin_routes.index,
      :notice => "#{admin_model.to_s.gsub(/Cambium::/, '')} deleted!")
  end

  private

    def set_object
      if admin_model.new.respond_to?(:slug) && params[:slug]
        slug = params[:"#{admin_model.to_s.underscore}_slug"] || params[:slug]
        @object = admin_model.find_by_slug(slug)
      else
        id = params[:"#{admin_model.to_s.underscore}_id"] || params[:id]
        @object = admin_model.find_by_id(id.to_i)
      end
      not_found if @object.nil?
      @obj = @object
    end

    def authenticate_admin!
      authenticate_user!
      not_found unless current_user.is_admin?
    end

    def create_params
      params
        .require(admin_model.to_s.tableize.singularize.to_sym)
        .permit(permitted_fields)
    end

    def relationship_fields
      relationships = []
      admin_form.fields.to_h.each do |k, v|
        relationships.push(field: k, class: v[:options]) if v[:type] == 'belongs_to'
      end
      relationships
    end

    def permitted_fields
      permitted = admin_form.fields.to_h.keys

      relationships = relationship_fields

      return permitted if relationships.empty?

      # Simple Form uses "fieldname_id" for relationship inputs
      relationship_keys = relationships.map { |r| r[:field] }
      permitted -= relationship_keys
      relationships.each do |r|
        permitted.push(foreign_key(r[:field]))
      end
      permitted
    end

    def foreign_key(field)
      @object.class.reflections[field.to_s].foreign_key
    end

    def update_params
      create_params
    end

    def set_activities
      @activities = PaperTrail::Version.order(:created_at => :desc)
        .includes(:item).limit(40)
      @activities = @activities
        .reject { |a| a.item.blank? || a.whodunnit.blank? }.first(20)
      @users = User.where(:id => @activities.collect(&:whodunnit)
        .reject(&:blank?).map(&:to_i))
    end

end
