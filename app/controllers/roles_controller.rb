# encoding: UTF-8

class RolesController < ApplicationController
  def index
    @roles = Role.paginate :page=>params[:page], :per_page=>session[:per_page]
  end

  def new
    @current_permission = []
    @permissions = Permission.get_all
    @user = User.find(session[:user_id])
  end

  def edit
    @current_permission = []
    @permissions = Permission.get_all
    @role = Role.find params[:id], :include => {:permission_role=>:permission}
    @role.permission_role.each do |pr|
      @current_permission << pr.permission.id
    end
    @user = User.find(session[:user_id])
  end

  def clone
    @current_permission = []
    @permissions = Permission.get_all
    role = Role.find params[:id], :include => {:permission_role=>:permission}
    role.permission_role.each do |pr|
      @current_permission << pr.permission.id
    end
    @user = User.find(session[:user_id])
    render :new
  end

  def create
    @role = Role.new params[:role]
    unless params[:permissions].nil?
      params[:permissions].each do |p|
        @role.permission_role << PermissionRole.new(:permission_id=>p)
      end
    end
    if @role.save
      flash[:notice] = 'Rol guardado con éxito'
      redirect_to :roles
    else
      new
      render :new
    end
  end

  def update
    @role = Role.find params[:id]
    @role.update_attributes(params[:role])
    @role.permission_role.clear
    unless params[:permissions].nil?
      params[:permissions].each do |p|
        pr = PermissionRole.create({:role_id=>@role.id, :permission_id=>p})
      end
    end
    if @role.save
      flash[:notice] = 'Rol guardado con éxito'
      redirect_to :roles
    else
      edit
      render :edit
    end
  end

  def destroy
    @role = Role.find params[:id]
    @role.eliminate
    if @role.errors.empty?
      flash[:notice] = "Rol eliminado con éxito"
    else
      logger.error("Error eliminando rol: #{@role.errors.inspect}")
      flash[:type] = 'error'
      if not @role.errors[:foreign_key].nil?
        flash[:notice] = 'El rol no se puede eliminar porque tiene registros asociados'
      elsif not @role.errors[:unknown].nil?
        flash[:notice] = @role.errors[:unknown]
      else
        flash[:notice] = "El rol no se ha podido eliminar"
      end
    end
    redirect_to :roles
  end
end
