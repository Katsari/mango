# encoding: UTF-8

class HoppersController < ApplicationController
  def index
    redirect_to scale_path(params[:scale_id])
  end

  def new
    fill_new
  end

  def edit
    fill_edit
  end

  def create
    @hopper = Scale.find(params[:scale_id]).hoppers.new params[:hopper]
    if @hopper.save
      @hopper_lot = @hopper.hopper_lot.new params[:hopper_lot]
      @hopper_lot.save
      flash[:notice] = 'Tolva guardada con éxito'
      redirect_to scale_path(@hopper.scale_id)
    else
      fill_new
      render :new
    end
  end

  def update
    @hopper = Hopper.find params[:id]
    @hopper.update_attributes(params[:hopper])
    if @hopper.save
      flash[:notice] = 'Tolva actualizada con éxito'
      redirect_to scale_path(@hopper.scale_id)
    else
      fill_edit
      render :edit
    end
  end

  def set_as_main_hopper
    @hopper = Hopper.find params[:id]
    @hopper.set_as_main_hopper()
    redirect_to scale_path(@hopper.scale_id)
  end

  def destroy
    @hopper = Hopper.find params[:id]
    @hopper.eliminate
    if @hopper.errors.size.zero?
      flash[:notice] = "Tolva eliminada con éxito"
    else
      logger.error("Error eliminando tolva: #{@hopper.errors.inspect}")
      flash[:type] = 'error'
      if not @hopper.errors[:foreign_key].nil?
        flash[:notice] = 'La tolva no se puede eliminar porque tiene registros asociados'
      elsif not @hopper.errors[:unknown].nil?
        flash[:notice] = @hopper.errors[:unknown]
      else
        flash[:notice] = "La tolva no se ha podido eliminar"
      end
    end
    redirect_to scale_path(@hopper.scale_id)
  end

  def change
    @hopper = Hopper.find params[:id]
    @lots = Lot.find :all,
                     :include => :ingredient,
                     :conditions => {:active => true, :in_use => true}
  end

  def do_change
	@hopper = Hopper.find params[:id], :include => :hopper_lot
	if @hopper.change(params[:change], session[:user_id])
	  flash[:notice] = "Cambio de lote realizado con éxito"
	else
	  flash[:type] = 'error'
      flash[:notice] = "No se pudo cambiar el lote de la tolva"
    end
	redirect_to scale_path(@hopper.scale_id)
  end

  def adjust
    hopper = Hopper.find params[:id], :include => :hopper_lot
    hopper_lot = hopper.current_hopper_lot
    if 
    fill
  end

  def do_adjust
	@hopper = Hopper.find params[:id], :include => :hopper_lot
	if @hopper.adjust(params[:adjust], session[:user_id])
	  flash[:notice] = "Ajuste realizado con éxito"
	else
	  flash[:type] = 'error'
      flash[:notice] = "No se pudo realizar el ajuste"
    end
	redirect_to scale_path(@hopper.scale_id)    
  end

  def fill
    @hopper = Hopper.find params[:id]
    @current_hopper_lot = @hopper.current_hopper_lot
  end

  def do_fill
    @hopper = Hopper.find params[:id]
    if @hopper.fill(params[:fill], session[:user_id])
      flash[:notice] = "Llenado realizado con éxito"
    else
      flash[:type] = 'error'
      flash[:notice] = "No se pudo realizar el llenado de la tolva"
    end
    redirect_to scale_path(@hopper.scale_id)
  end
  private

  def fill_new
    @lots = Lot.find :all,
                     :include => :ingredient,
                     :conditions => {:active => true, :in_use => true}
    @scales = Scale.all
  end

  def fill_edit
    @scales = Scale.all
    @hopper = Hopper.find params[:id]
  end
end
