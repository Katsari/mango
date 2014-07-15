# encoding: UTF-8

include MangoModule

class IngredientsController < ApplicationController
  def index
    @transactions_enabled = is_mango_feature_available("transactions")
    @ingredients = Ingredient.paginate :page=>params[:page], :per_page=>session[:per_page],
                   :order => ['stock_below_minimum desc']
  end
  
  def new
    @transactions_enabled = is_mango_feature_available("transactions")
  end

  def edit
    @transactions_enabled = is_mango_feature_available("transactions")
    @ingredient = Ingredient.find params[:id]
  end

  def create
    @ingredient = Ingredient.new params[:ingredient]
    @ingredient.minimum_stock = 0 unless is_mango_feature_available("transactions")
    if @ingredient.save
      flash[:notice] = 'Materia prima guardada con éxito'
      redirect_to :ingredients
    else
      render :new
    end
  end
  
  def update
    @ingredient = Ingredient.find params[:id]
    @ingredient.update_attributes(params[:ingredient])
    if @ingredient.save
      flash[:notice] = 'Materia prima actualizada con éxito'
      redirect_to :ingredients
    else
      render :edit
    end
  end
  
  def destroy
    @ingredient = Ingredient.find params[:id]
    @ingredient.eliminate
    if @ingredient.errors.size.zero?
      flash[:notice] = "Materia prima eliminada con éxito"
    else
      logger.error("Error eliminando ingredient: #{@ingredient.errors.inspect}")
      flash[:type] = 'error'
      if not @ingredient.errors[:foreign_key].nil?
        flash[:notice] = 'La materia prima no se puede eliminar porque tiene registros asociados'
      elsif not @ingredient.errors[:unknown].nil?
        flash[:notice] = @ingredient.errors[:unknown]
      else
        flash[:notice] = "La materia prima no se pudo eliminar"
      end
    end
    redirect_to :ingredients
  end

  def lots
    @transactions_enabled = is_mango_feature_available("transactions")
    @ingredient = Ingredient.find params[:id]
    @lots = @ingredient.lots
                       .includes(:ingredient)
                       .where(active: true)
                       .paginate(page: params[:page], per_page: session[:per_page])
    @stock = @ingredient.lots
                        .where(active: true)
                        .sum(:stock)
                        .round(2)
    session[:return_to] = request.referer
  end

  def search
    pattern = params['ingredient']['pattern'] + '%'
    opt = params['ingredient']['option'].to_i
    condition = (opt.zero?) ? "code LIKE ?" : "name LIKE ?"
    @ingredients = Ingredient.where([condition, pattern])
    respond_to do |format|
      format.js { render :layout=>false, :locals => {:ingredients=>@ingredients} } #{render :search, :layout => false} - render :content_type => 'text/javascript'
    end
  end
  
  def catalog
    @ingredients = Ingredient.find :all
    respond_to do |format|
      format.js { render :layout=>false }
    end
  end

  def select
    @code = params[:code]
    @name = params[:name]
    respond_to do |format|
      format.js { render :layout=>false }
    end
  end
end
