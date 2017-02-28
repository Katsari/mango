class Warehouse < ActiveRecord::Base
  attr_protected :id

  belongs_to :ingredient
  belongs_to :product
  belongs_to :warehouse_types

  has_many :transactions
  has_many :warehouses_contents, :dependent => :destroy

  accepts_nested_attributes_for :warehouses_contents, allow_destroy: true, reject_if: lambda { |a| a[:content_id].blank? }

  validates :name, :code, presence: true
  validates :content_id, presence: true, unless: :sacks
  validates :code, uniqueness: true
  validates :code, :name, length: {within: 3..40}
  validates :stock, numericality: {greater_than_or_equal_to: 0}


  def adjust(params)
    if is_a_number? params[:stock]
      new_stock = params[:stock].to_f
      if new_stock < 0
        logger.debug("stock can't be negative")
        false
      elsif new_stock > self.size
        logger.debug("stock exceeds capacity")
        false
      else
        true
      end
    else
      false
    end
  end


  def new_amount(amount)
    new_stock = self.stock + amount.to_f
    new_stock.to_f
  end


  def fill(params)
    if is_a_number? params[:amount]
      amount = params[:amount].to_f
      logger.debug("Stock: #{self.stock}")
      logger.debug("Capacidad: #{self.size}")
      if amount <= 0 or self.stock + amount > self.size
        return false
      end
      w = Warehouse.new
      w.stock = amount
      w.save
    else
      return false
    end
  end
  

  def change(params, user_id)
    if is_a_number? params[:ingredient_id]
      new_ingredient_id = params[:ingredient_id].to_i
      if @warehouse.ingredient_id == new_ingredient_id
        logger.debug("ingredient can't be the same")
        false
      else
        true
      end
    else
      false
    end
  end

  def eliminate
    begin
      self.destroy
    rescue ActiveRecord::StatementInvalid => ex
      puts ex.inspect
      errors.add(:foreign_key, 'no se puede eliminar porque tiene registros asociados')
    rescue Exception => ex
      errors.add(:unknown, ex.message)
    end
  end

  def set_as_main_warehouse
    warehouses = Warehouse.where(content_id: self.content_id, content_type: self.content_type)
    unless warehouses.empty?
      Warehouse.update_all('main = false', :id => warehouses.map {|wh| wh.id})
    end
    self.update_attributes(main: true)
  end

  def set_main_warehouse
    warehouses = Warehouse.where(content_id: self.content_id, content_type: self.content_type)
    if warehouses.length == 1
      self.update_attributes(main: true)
    end
  end
  
  def to_collection_select
    "#{self.warehouse_types.name} - #{self.code} - #{self.name}"
  end


  def is_a_number?(s)
    s.to_s.match(/\A[+-]?\d+?(\.\d+)?\Z/) != nil
  end
end