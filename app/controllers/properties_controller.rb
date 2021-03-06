# encoding: UTF-8
class PropertiesController < ApplicationController
  before_filter :authorize_user_is_admin
  layout 'admin'

  before_filter :find_property, only: [:edit, :update, :destroy]

  # GET /properties
  # GET /properties.xml
  def index
    @properties = current_user.company.properties
    respond_to do |format|
      format.html # index.html.erb
      format.xml { render :xml => @properties }
    end
  end

  # GET /properties/new
  # GET /properties/new.xml
  def new
    @property = Property.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml { render :xml => @property }
    end
  end

  # GET /properties/1/edit
  def edit
  end

  # POST /properties
  # POST /properties.xml
  def create
    @property = Property.new(property_attributes)
    @property.property_values.build(new_property_values_attributes) if new_property_values_attributes.present?
    @property.company = current_user.company

    respond_to do |format|
      if @property.save
        flash[:success] = t('flash.notice.model_created', model: Property.model_name.human)
        format.html { redirect_to(edit_property_path(@property)) }
        format.xml { render :xml => @property, :status => :created, :location => @property }
      else
        format.html { render :action => 'new' }
        format.xml { render :xml => @property.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /properties/1
  # PUT /properties/1.xml
  def update
    update_existing_property_values(@property)
    not_empty_property_value = new_property_values_attributes[0]['value'] if new_property_values_attributes.present?
    @property.property_values.build(new_property_values_attributes) if not_empty_property_value.present?

    saved = @property.update_attributes(property_attributes)
    # force company in case somebody passes in company_id param
    @property.company = current_user.company
    saved &&= @property.save

    respond_to do |format|
      if saved
        flash[:success] = t('flash.notice.model_updated', model: Property.model_name.human)
        format.html { redirect_to(edit_property_path(@property)) }
        format.xml { head :ok }
      else
        format.html { render :action => 'edit' }
        format.xml { render :xml => @property.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /properties/1
  # DELETE /properties/1.xml
  def destroy
    @property.destroy

    respond_to do |format|
      format.html { redirect_to(properties_url) }
      format.xml { head :ok }
    end
  end

  def order
    if property_values_ids
      values = property_values_ids.reject(&:empty?).map { |id| PropertyValue.find(id) }
      # if it's a new record, we can just ignore this (because update will use the correct order)
      if values.first.property
        values.each_with_index do |v, i|
          v.position = i
          v.save
        end
      end
    end

    render :text => ''
  end

  # GET /properties/remove_property_value_dialog
  # params:
  #   property_value_id
  def remove_property_value_dialog
    @pv = current_user.company.property_values.find_by_id(params[:property_value_id])
    render :layout => false
  end

  # POST /properties/remove_property_value
  # params:
  #   property_value_id
  #   replace_with
  def remove_property_value
    @pv = current_user.company.property_values.find_by_id(params[:property_value_id])
    unless params[:replace_with].blank?
      # if replace with another value
      @replace_with = current_user.company.property_values.find_by_id(params[:replace_with])
      @pv.task_property_values.each { |tpv| @replace_with.task_property_values << tpv }
      @pv.task_filter_qualifiers.each { |tfq| @replace_with.task_filter_qualifiers << tfq }
    end
    # reload is important
    @pv.reload.destroy
    return render :json => {:success => true}
  end

  private

  def update_existing_property_values(property)
    return if !property or !property_values_attributes

    property.property_values.each do |pv|
      posted_vals = property_values_attributes[pv.id.to_s]
      if posted_vals
        pv.update_attributes(posted_vals)
      else
        property.property_values.delete(pv)
      end
    end
  end

  def find_property
    @property = current_user.company.properties.find(params[:id])
  end

  def property_attributes
    params.fetch(:property, {}).permit :name, :id, :mandatory, :default_sort, :default_color
  end

  def new_property_values_attributes
    params.permit(new_property_values: [:value, :default, :color, :icon_url]).fetch :new_property_values, []
  end

  def property_values_attributes
    params.permit(property_values: [:value, :default, :color, :icon_url]).fetch :property_values, []
  end

  def property_values_ids
    params.fetch(:property_values, {})
  end

end
