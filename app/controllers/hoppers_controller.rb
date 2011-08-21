class HoppersController < ApplicationController
  def index
    @hoppers = Hopper.find_active
    puts @hoppers.inspect
  end

  def new
    @ingredients = Ingredient.find :all, :order => 'name ASC'
  end

  def edit
    @ingredients = Ingredient.find :all, :order => 'name ASC'
    @hopper = Hopper.find params[:id]
  end

  def create
    @hopper = Hopper.new :number => params[:hopper][:number]
    if @hopper.save
      if @hopper.update_ingredient(params[:hopper][:hopper_ingredient])
        flash[:notice] = 'Tolva guardada con éxito'
      else
        flash[:notice] = 'La tolva fue guardada con éxito pero no se guardó el ingrediente asociado'
      end
      redirect_to :hoppers
    else
      new
      render :new
    end
  end

  def update
    @hopper = Hopper.find params[:id]
    if @hopper.update_ingredient(params[:hopper][:hopper_ingredient])
      flash[:notice] = 'Tolva actualizada con éxito'
      redirect_to :hoppers
    else
      edit
      render :edit
    end
  end

  def destroy
    @hopper = Hopper.find params[:id]
    @hopper.eliminate
    if @hopper.errors.size.zero?
      flash[:notice] = "Tolva eliminada con éxito"
    else
      flash[:notice] = "La tolva no se ha podido eliminar"
      flash[:type] = 'error'
    end
    redirect_to :hoppers
  end
end