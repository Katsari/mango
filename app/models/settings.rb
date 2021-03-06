class Settings < ActiveRecord::Base
  attr_protected :id

  validates :hopper_minimum_level, :presence => true,
            :numericality => true, :inclusion => 0..100
  validates :ticket_reception_diff, :ticket_dispatch_diff, :presence => true,
            :numericality => true, :inclusion => 0..100
  after_save :check_hoppers_stock

  def check_hoppers_stock
    hoppers_lots = HopperLot.includes({:hopper => {:scale => {}}, :lot => {}}).where(:active => true)
    hoppers_lots.each do |hl|
      hl.check_hopper_stock
    end
    true
  end
end
