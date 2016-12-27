class PurchaseOrder < ActiveRecord::Base
  attr_protected :id

  belongs_to :client

  def to_collection_select
    "#{self.code}"
  end

  def self.import(purchasesorders)
    purchasesorders.each do |purchases|
      if Ingredient.where(code: purchases['mat_code']).empty?
        Ingredient.create code: purchases['mat_code'],
                          name: purchases['mat_name']
        ingredient = Ingredient.where(code: purchases['mat_code'])
        Lot.create code: purchases['mat_code'],
                   ingredient_id: ingredient[0].id,
                   density: 1
      end
      if Client.where(code: purchases['client_code']).empty?
        Client.create code: purchases['client_code'],
                      name: purchases['client_name'],
                      ci_rif: purchases['client_rif'],
                      address: purchases['client_address'],
                      tel1: purchases['client_phone']
      end
      client = Client.where(code: purchases['client_code'])
      sack = purchases['sack'].downcase == 's' ? true : false
      if PurchaseOrder.where(code: purchases['order_code']).empty?
        PurchaseOrder.create code: purchases['order_code'],
                             id_client: client[0].id,
                             closed: false
      end
      ingredient = Ingredient.where(code: purchases['mat_code'])
      purchase_order_act = PurchaseOrder.where(code: purchases['order_code'])
      if PurchaseOrderItems.where(id_purchase_order: purchase_order_act[0].id, 
                                  position: purchases['position']).empty?
      PurchaseOrderItems.create id_purchase_order: purchase_order_act[0].id,
                                id_ingredient: ingredient[0].id,
                                position:purchases['position'],
                                quantity:purchases['quantity'],
                                sack:sack,
                                total_weight: purchases['total_weight']
      end
    end
  end

end
