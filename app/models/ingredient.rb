class Ingredient < ActiveRecord::Base
  has_many :ingredient_recipe
  has_many :ingredient_medicament_recipe
  has_many :lots
  belongs_to :base_unit
  has_many :ingredient_parameter_type_ranges

  accepts_nested_attributes_for :ingredient_parameter_type_ranges

  before_save :check_stock

  validates :name, :code, :minimum_stock, presence: true
  validates :code, uniqueness: true
  validates :code, :name, length: {within: 3..40}
  validates :minimum_stock, numericality: {greater_than_or_equal_to: 0}

  def to_collection_select
    "#{self.code} - #{self.name}"
  end

  def generate_parameter_type_ranges
    LotParameterType.all.each do |pt|
      r = pt.ingredient_parameter_type_ranges.new
      r.ingredient_id = self.id
      r.save
    end
  end

  def check_stock
    total_stock = self.lots.where(active: true).sum(:stock)
    self.stock_below_minimum = total_stock < self.minimum_stock
    true
  end
end
