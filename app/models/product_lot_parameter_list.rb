class ProductLotParameterList < ActiveRecord::Base
  attr_protected :id

  has_many :product_lot_parameters, :dependent => :destroy
  belongs_to :product_lot

  accepts_nested_attributes_for :product_lot_parameters

  validates_presence_of :product_lot

  after_create :generate_product_lot_parameters

  def generate_product_lot_parameters
    ProductLotParameterType.all.each do |pt|
      product_lot_parameter = self.product_lot_parameters.new
      product_lot_parameter.product_lot_parameter_type = pt
      product_lot_parameter.value = pt.default_value
      product_lot_parameter.save
    end
  end

  def parameters_with_range
    parameters = []
    self.product_lot_parameters
      .includes(:product_lot_parameter_type)
      .each do |plp|
        range = ProductParameterTypeRange
          .where(product_lot_parameter_type_id: plp.product_lot_parameter_type_id,
                 product_id: self.product_lot.product_id).first
        parameters << {
          "name" => plp.product_lot_parameter_type.name,
          "value" => plp.product_lot_parameter_type.is_string ? plp.string_value : plp.value,
          "unit" => plp.product_lot_parameter_type.unit,
          "max" => range.nil? ? nil : range.max,
          "min" => range.nil? ? nil : range.min
        }
      end
    parameters
  end
end
