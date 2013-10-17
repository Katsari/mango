class EasyModel
  def self.order_lots_parameters(order_code)
    joins = {:lot => {:hopper_lot => {:batch_hopper_lot => {:batch => {:order => {}}}}}}
    includes = {:lot_parameters => {:lot_parameter_type => {}},
                :lot => {:ingredient => {}}}
    lot_parameter_lists = LotParameterList.joins(joins).includes(includes).where(['orders.code = ?', order_code]).order('ingredients.code asc')

    joins = {:product_lot => {:order => {}}}
    includes = {:product_lot_parameters => {:product_lot_parameter_type => {}},
                :product_lot => {:product => {}}}
    product_lot_parameter_list = ProductLotParameterList.joins(joins).includes(includes).where(['orders.code = ?', order_code]).first

    return nil if lot_parameter_lists.empty? and product_lot_parameter_list.nil?

    order = Order.find_by_code order_code
    data = self.initialize_data("Caracteristicas de la orden #{order_code}")
    data['order'] = order.code
    data['client'] = "#{order.client.code} - #{order.client.name}"
    data['recipe'] = "#{order.recipe.code} - #{order.recipe.name}"
    data['version'] = order.recipe.version
    data['product'] = order.product_lot.nil? ? "" : "#{order.product_lot.product.code} - #{order.product_lot.product.name}"
    data['start_date'] = order.calculate_start_date()
    data['end_date'] = order.calculate_end_date()
    data['tables'] = []

    lot_parameter_lists.each do |lpl|
      data['tables'] << {
        "title" => "#{lpl.lot.ingredient.name} (Lote #{lpl.lot.code})",
        "table" => lpl.parameters_with_range
      }
    end

	unless product_lot_parameter_list.nil?
	  data['tables'] << {
        "title" => "#{product_lot_parameter_list.product_lot.product.name} (Lote #{product_lot_parameter_list.product_lot.code})",
        "table" => product_lot_parameter_list.parameters_with_range
      }
    end

    return data
  end

  def self.hopper_transactions(hopper_id, start_datetime, end_datetime)
    hopper = Hopper.find_by_id hopper_id, :include => :scale
    return nil if hopper.nil?

    includes = {:hopper_lot => {:lot => {:ingredient => {}}}, 
                :hopper_lot_transaction_type => {},
                :user => {}}
    hlts = HopperLotTransaction.includes(includes)
    hlts = hlts.where(:created_at => (start_datetime..end_datetime))
    hlts = hlts.where(['hoppers_lots.hopper_id = ?', hopper_id])   
    return nil if hlts.empty?
    
    data = self.initialize_data("Movimientos de tolva #{hopper.name} (#{hopper.scale.name})")
    data['since'] = self.print_range_date(start_datetime, true)
    data['until'] = self.print_range_date(end_datetime, true)
    data['results'] = []

    hlts.each do |hlt|
      amount = hlt.hopper_lot_transaction_type.sign == "+" ? hlt.amount : -1 * hlt.amount
      data['results'] << {
        'code' => hlt.hopper_lot.lot.code,
        'ingredient' => hlt.hopper_lot.lot.ingredient.name,
        'time' => hlt.created_at.strftime("%d/%m/%Y %H:%M:%S"),
        'user' => hlt.user.login,
        'type' => hlt.hopper_lot_transaction_type.code,
        'amount' => amount,
        'stock' => hlt.stock_after
      }
    end
    return data
  end

  def self.hoppers_stock(datetime)
  
  end

  #This method is nasty as fuck because it only works for PROPORCA
  def self.stats(start_date, end_date)
    @orders = Order.find :all, :include=>{:order_stats => {}, :batch => {}, :recipe => {}}, :conditions=>['batches.start_date >= ? and batches.end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['batches.start_date ASC']

    data = self.initialize_data("Estadisticas de produccion")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    return nil if @orders.empty?

    @orders.each do |order|
      n1, n2, n3, n4, n5, n6 = 0, 0, 0, 0, 0, 0
      tmp_batch_bal_macro = 0
      tmp_desc_bal_macro = 0
      batches_hora_mezc = 0
      tmp_mol_1 = 0
      tmp_mol_2 = 0
      tmp_mol_3 = 0
      order.order_stats.each do |order_stat|
        if order_stat.order_stat_type_id == 1
          n1 += 1
          tmp_batch_bal_macro += order_stat.value
        elsif order_stat.order_stat_type_id == 2
          n2 += 1
          tmp_desc_bal_macro += order_stat.value
        elsif order_stat.order_stat_type_id == 3
          n3 += 1
          tmp_mol_1 += order_stat.value
        elsif order_stat.order_stat_type_id == 4
          n4 += 1
          tmp_mol_2 += order_stat.value
        elsif order_stat.order_stat_type_id == 5
          n5 += 1
          tmp_mol_3 += order_stat.value
        elsif order_stat.order_stat_type_id == 6
          n6 += 1
          batches_hora_mezc += order_stat.value
        end
      end
      tmp_batch_bal_macro = n1.zero? ? 0 : tmp_batch_bal_macro / n1
      tmp_desc_bal_macro = n2.zero? ? 0 : tmp_desc_bal_macro / n2
      tmp_mol_1 = n3.zero? ? 0 : tmp_mol_1 / n3
      tmp_mol_2 = n4.zero? ? 0 : tmp_mol_2 / n4
      tmp_mol_3 = n5.zero? ? 0 : tmp_mol_3 / n5
      batches_hora_mezc = n6.zero? ? 0 : batches_hora_mezc / n6
      data['results'] << {
        'order' => order.code,
        'recipe_name' => order.recipe.name,
        'real_batches' => order.get_real_batches,
        'tmp_batch_bal_macro' => self.int_seconds_to_time_string(tmp_batch_bal_macro),
        'tmp_desc_bal_macro' => self.int_seconds_to_time_string(tmp_desc_bal_macro),
        'batches_hora_mezc' => batches_hora_mezc,
        'tmp_mol_1' => self.int_seconds_to_time_string(tmp_mol_1),
        'tmp_mol_2' => self.int_seconds_to_time_string(tmp_mol_2),
        'tmp_mol_3' => self.int_seconds_to_time_string(tmp_mol_3),
      }
    end
    return data
  end
  #This one is also nasty as fuck for the same reason
  def self.order_stats(order_code)
    @order = Order.find_by_code order_code
    if @order.nil?
      return nil
    end

    data = self.initialize_data('Estadisticas de orden')
    data['order'] = @order.code
    data['client'] = "#{@order.client.code} - #{@order.client.name}"
    data['recipe'] = "#{@order.recipe.code} - #{@order.recipe.name}"
    data['version'] = @order.recipe.version
    data['comment'] = @order.comment
    data['product'] = @order.product_lot.nil? ? "" : "#{@order.product_lot.product.code} - #{@order.product_lot.product.name}"
    data['start_date'] = @order.calculate_start_date()
    data['end_date'] = @order.calculate_end_date()
    data['real_batches'] = @order.get_real_batches().to_s
    data['results'] = []

    OrderStatType.all.each do |ost|
      stats = OrderStat.find :all, :conditions => ['order_id = ? and order_stat_type_id = ?', @order.id, ost.id]
      stat_value = stats.any? ? stats.inject(0.0) {|sum, stat| sum + stat.value } / stats.count : 0
      unless ost.id == 6 #Ewwww
        stat_value = self.int_seconds_to_time_string(stat_value)
      end
      data['results'] << {
        'stat_name' => ost.description,
        'stat_value' => stat_value
      }
    end
    return data
  end

  def self.order_details_real(order_code)
    _order_details = order_details(order_code)
    return nil if _order_details.nil?
    return nil if _order_details["product_total"].to_f == 0
    return nil unless _order_details["real_production"].present?
    real_production = _order_details["real_production"].to_f
    product_total = _order_details["product_total"].to_f
    _order_details["results"].each do |result|
      real_kg = result["real_kg"]
      std_kg = result["std_kg"]
      real_real_kg = real_kg * real_production / product_total # DAE fer reelz? LOL
      var_kg = real_real_kg - std_kg
      var_perc = var_kg / std_kg * 100
      result["real_real_kg"] = real_real_kg  
      result["var_kg"] = var_kg  
      result["var_"] = var_perc  
    end
    _order_details
  end

  def self.alarms(start_date, end_date, alarm_type_id)
    if alarm_type_id == 0
      conditions = {:date=>(start_date)..((end_date) + 1.day)}
    else
      conditions = {:alarm_type_id=>alarm_type_id, :date=>(start_date)..((end_date) + 1.day)}
    end

    @alarms = Alarm.find :all, :conditions => conditions
    return nil if @alarms.length.zero?

    data = self.initialize_data("Reporte de alarmas")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['table'] = []

    @alarms.each do |alarm|
      data['table'] << {
          'order_code' => alarm.order.code,
          'date' => alarm.date.strftime("%d/%m/%Y %H:%M:%S"),
          'description' => alarm.description,
        }
    end
    return data
  end

  def self.alarms_per_order(order_code, alarm_type_id)
    @order = Order.find_by_code order_code
    return nil if @order.nil?
    if alarm_type_id == 0
      @alarms = @order.alarms
    else
      @alarms = Alarm.find :all, :conditions => ['alarm_type_id = ? and order_id = ?', alarm_type_id, @order.id]
    end
    return nil if @order.alarms.empty?

    data = self.initialize_data("Alarmas de Orden #{order_code}")
    data['table'] = []

    @alarms.each do |alarm|
      data['table'] << {
          'date' => alarm.date.strftime("%d/%m/%Y %H:%M:%S"),
          'description' => alarm.description,
        }
    end
    return data
  end

  def self.ticket(ticket_id)
    @ticket = Ticket.find ticket_id
    return nil if @ticket.open?

    data = self.initialize_data("Ticket #{@ticket.number} - #{@ticket.ticket_type.code}")

    data['number'] = @ticket.number
    data['incoming_date'] = @ticket.incoming_date.strftime("%d/%m/%Y %H:%M:%S")
    data['outgoing_date'] = @ticket.outgoing_date.strftime("%d/%m/%Y %H:%M:%S")
    if @ticket.ticket_type_id == 1 # Reception ticket
      data['client_title'] = 'Proveedor:'
    else # Dispatch ticket
      data['client_title'] = 'Cliente:'
    end

    data['client_code'] = @ticket.client.code
    data['client_name'] = @ticket.client.name
    data['user_name'] = @ticket.user.name
    data['driver_name'] = @ticket.driver.name
    data['driver_id'] = @ticket.driver.ci
    data['carrier'] = @ticket.truck.carrier.name
    data['license_plate'] = @ticket.truck.license_plate
    data['provider_document_number'] = @ticket.provider_document_number.to_s
    data['incoming_weight'] = @ticket.incoming_weight.to_s + " Kg"
    data['outgoing_weight'] = @ticket.outgoing_weight.to_s + " Kg"
    data['provider_weight'] = @ticket.provider_weight.nil? ? "" : @ticket.provider_weight.to_s + " Kg"
    data['gross_weight'] = @ticket.get_gross_weight.to_s + " Kg"
    data['tare_weight'] = @ticket.get_tare_weight.to_s + " Kg"
    data['net_weight'] = @ticket.get_net_weight.to_s + " Kg"

    data['comment1'] = " "
    data['comment2'] = " "
    data['comment3'] = " "
    data['comment4'] = " "
    data['comment5'] = " "
    
    if @ticket.ticket_type_id == 1
      data['dif_label'] = "Dif.:"
      data['dif'] = (@ticket.provider_weight - @ticket.get_net_weight).round(2).to_s + " Kg"
    else
      data['dif_label'] = ""
      data['dif'] = ""
    end

    # I fucking hate easyreport
    comments = @ticket.comment.split(/\n/)
    if comments[0]
      data['comment1'] = comments[0]
    end
    if comments[1]
      data['comment2'] = comments[1]
    end
    if comments[2]
      data['comment3'] = comments[2]
    end
    if comments[3]
      data['comment4'] = comments[3]
    end
    if comments[4]
      data['comment5'] = comments[4]
    end

    data['transactions'] = []
    @ticket.transactions.each do |t|
      sacks = "-"
      sack_weight = "-"
      if t.sack
        sacks = t.sacks.to_s
        sack_weight = t.sack_weight.to_s + "Kg"
      end
      data['transactions'] << {
        'code' => t.get_lot.code,
        'name' => t.get_content.name,
        'sacks' => sacks,
        'sack_weight' => sack_weight,
        'amount' => t.amount
      }
    end

    return data
  end

  def self.tickets_transactions(start_date, end_date, ticket_type_id, content_type)
    @tickets = Ticket.find :all, :include => {:transactions => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and outgoing_date >= ? and outgoing_date <= ?', ticket_type_id, content_type, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones" : "Despachos"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        #TODO Right way to discard pallets transactions
        if content_type == 2 and transaction.get_content.code == "1000"
          next
        end

        sacks = "-"
        sack_weight = "-"
        if transaction.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data
  end

  def self.tickets_transactions_per_clients(start_date, end_date, ticket_type_id, content_type, clients_codes)
    @tickets = Ticket.find :all, :include => {:transactions => {}, :client => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and clients.code in (?) and outgoing_date >= ? and outgoing_date <= ?', ticket_type_id, content_type, clients_codes, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones" : "Despachos"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        if content_type == 2 and transaction.get_content.code == "1000"
          next
        end
        sacks = "-"
        sack_weight = "-"
        if transaction.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data
  end

  def self.tickets_transactions_per_contents(start_date, end_date, ticket_type_id, content_type, contents_codes)
    @tickets = Ticket.find :all, :include => {:transactions => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and outgoing_date >= ? and outgoing_date <= ?', ticket_type_id, content_type, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones" : "Despachos"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        unless contents_codes.include? transaction.get_content.code
          next
        end

        sacks = "-"
        sack_weight = "-"
        if transaction.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data
  end

  def self.tickets_transactions_per_contents_per_clients(start_date, end_date, ticket_type_id, content_type, contents_codes, clients_codes)
    @tickets = Ticket.find :all, :include => {:client => {}, :transactions => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and clients.code in (?) and outgoing_date >= ? and outgoing_date <= ?', ticket_type_id, content_type, clients_codes, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones" : "Despachos"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        unless contents_codes.include? transaction.get_content.code
          next
        end

        sacks = "-"
        sack_weight = "-"
        if transaction.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data
  end

  def self.tickets_transactions_per_carrier(start_date, end_date, ticket_type_id, content_type, carrier_id)
    @tickets = Ticket.find :all, :include => {:transactions => {}, :truck => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and outgoing_date >= ? and outgoing_date <= ? and trucks.carrier_id = ?', ticket_type_id, content_type, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), carrier_id], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones por Transportista" : "Despachos por Transportista"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    carrier = Carrier.find(carrier_id)
    data['carrier'] = carrier.name
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        if content_type == 2 and transaction.get_content.code == "1000"
          next
        end
        sacks = "-"
        sack_weight = "-"
        if t.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data
  end

  def self.tickets_transactions_per_driver(start_date, end_date, ticket_type_id, content_type, driver_id)
    @tickets = Ticket.find :all, :include => {:transactions => {}, :truck => {}}, :conditions => ['open = FALSE and ticket_type_id = ? and transactions.content_type = ? and outgoing_date >= ? and outgoing_date <= ? and driver_id = ?', ticket_type_id, content_type, self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), driver_id], :order=>['tickets.number ASC']

    return nil if @tickets.length.zero?

    ticket_type_title = (ticket_type_id == 1) ? "Recepciones por Transportista" : "Despachos por Transportista"
    content_type_title = (content_type == 1) ? "Materia Prima" : "Producto Terminado"

    data = self.initialize_data("#{ticket_type_title} de #{content_type_title}")
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    driver = Driver.find(driver_id)
    data['driver'] = "#{driver.ci} - #{driver.name}"
    data['table1'] = []

    @tickets.each do |ticket|
      ticket.transactions.each do |transaction|
        if content_type == 2 and transaction.get_content.code == "1000"
          next
        end
        sacks = "-"
        sack_weight = "-"
        if t.sack
          sacks = transaction.sacks.to_s
          sack_weight = transaction.sack_weight.to_s + " Kg"
        end

        data['table1'] << {
          'number' => ticket.number,
          'client' => ticket.client.name,
          'content_name' => transaction.get_content.name,
          'sacks' => sacks,
          'sack_weight' => sack_weight,
          'amount' => transaction.amount,
        }
      end
    end
    return data

  end

  def self.daily_production(start_date, end_date)
    @orders = Order.find :all, :include=>['batch', 'recipe', 'medicament_recipe', 'client'], :conditions=>['batches.start_date >= ? and batches.end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['batches.start_date ASC']
    return nil if @orders.length.zero?

    data = self.initialize_data('Produccion Diaria por Fabrica')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    @orders.each do |o|
      rtotal = Batch.get_real_total(o.id)
      rbatches = o.get_real_batches
      stotal = 0
      unless o.medicament_recipe.nil?
        stotal = (o.recipe.get_total() + o.medicament_recipe.get_total()) * rbatches
      else
        stotal = o.recipe.get_total() * rbatches
      end
      var_kg = rtotal - stotal
      var_perc = (var_kg * 100.0) / stotal
      data['results'] << {
        'order' => o.code,
        'date' => o.calculate_short_start_date,
        'recipe_code' => o.recipe.code,
        'recipe_name' => o.recipe.name,
        'recipe_version' => o.recipe.version,
        'client_code' => o.client.code,
        'client_name' => o.client.name,
        'real_batches' => rbatches.to_s,
        'total_standard' => stotal.to_s,
        'total_real' => rtotal.to_s,
        'var_kg' => var_kg.to_s,
        'var_perc' => var_perc.to_s
      }
    end

    return data
  end

  def self.real_production(start_date, end_date)
    @orders = Order.find :all, :include=>['batch', 'recipe', 'medicament_recipe', 'client'], :conditions=>['batches.start_date >= ? and batches.end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['batches.start_date ASC']
    return nil if @orders.length.zero?

    data = self.initialize_data('Produccion Fisico')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    @orders.each do |o|
      rbatches = o.get_real_batches()
      ttotal = Batch.get_real_total(o.id)
      rtotal = o.real_production.present? ? o.real_production : ttotal
      loss = rtotal - ttotal
      loss_perc = (loss * 100.0) / ttotal
      data['results'] << {
        'order' => o.code,
        'date' => o.calculate_short_start_date,
        'recipe_name' => o.recipe.name,
        'recipe_version' => o.recipe.version,
        'client_name' => o.client.name,
        'real_batches' => rbatches.to_s,
        'theoric_total' => ttotal.to_s,
        'real_total' => rtotal.to_s,
        'loss' => loss.to_s,
        'loss_perc' => loss_perc.to_s
      }
    end

    return data
  end

  def self.consumption_per_ingredient_per_orders(start_date, end_date, ingredient_code)
    @orders = Order.find :all, :include=>['batch'], :conditions=>['batches.start_date >= ? and batches.end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['batches.start_date ASC']
    return nil if @orders.length.zero?
    
    @ingredient = Ingredient.find_by_code ingredient_code
    return nil if @ingredient.nil?

    data = self.initialize_data('Consumo por ingrediente por Ordenes de Produccion')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []
    data['ingredient'] = "#{@ingredient.code} - #{@ingredient.name}"

    @orders.each do |o|
      order_ingredients = {}
      o.recipe.ingredient_recipe.each do |ir|
        order_ingredients[ir.ingredient.code] = ir.amount
      end
      unless o.medicament_recipe.nil?
        o.medicament_recipe.ingredient_medicament_recipe.each do |imr|
          order_ingredients[imr.ingredient.code] = imr.amount
        end
      end

      unless order_ingredients.has_key? ingredient_code
        next
      end

      total_std = order_ingredients[ingredient_code] * o.get_real_batches()
      total_real = 0
      
      o.batch.each do |b|
        b.batch_hopper_lot.each do |bhl|
          if bhl.hopper_lot.lot.ingredient_id == @ingredient.id
            total_real += bhl.amount
            next
          end
        end
      end

      var_kg = total_real - total_std
      var_perc = var_kg * 100 / total_std
      rbatches = o.get_real_batches()
      
      data['results'] << {
        'order' => o.code,
        'date' => o.calculate_short_start_date,
        'recipe_code' => o.recipe.code,
        'recipe_name' => o.recipe.name,
        'recipe_version' => o.recipe.version,
        'real_batches' => rbatches.to_s,
        'total_standard' => total_std.to_s,
        'total_real' => total_real.to_s,
        'var_kg' => var_kg.to_s,
        'var_perc' => var_perc.to_s
      }
    end

    return data
  end

  def self.order_duration(start_date, end_date)
    @orders = Order.find :all, :include=>['batch', 'recipe', 'client'], :conditions=>['batches.start_date >= ? and batches.end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)], :order=>['batches.start_date ASC']
    return nil if @orders.length.zero?

    data = self.initialize_data('Duracion de Orden de Produccion')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    std_total = 0
    real_total = 0
    @orders.each do |o|
      rtotal = Batch.get_real_total(o.id)
      rbatches = o.get_real_batches
      stotal = 0
      unless o.medicament_recipe.nil?
        stotal = (o.recipe.get_total() + o.medicament_recipe.get_total()) * rbatches
      else
        stotal = o.recipe.get_total() * rbatches
      end
      d = o.calculate_duration
      order_duration = d['duration']
      start_time = d['start_date']
      end_time = d['end_date']
      average_batch_duration = order_duration / rbatches rescue 0
      average_tons_per_hour = rtotal / (order_duration / 60) / 1000 rescue 0
      data['results'] << {
        'order' => o.code,
        'date' => o.calculate_short_start_date,
        'recipe_code' => o.recipe.code,
        'recipe_name' => o.recipe.name,
        'average_tons_per_hour' => average_tons_per_hour.to_s,
        'average_batch_duration' => average_batch_duration.to_s,
        'order_duration' => order_duration.to_s,
        'real_batches' => rbatches.to_s,
        'start_time' => start_time,
        'end_time' => end_time,
        'total_real' => rtotal.to_s,
        'total_standard' => stotal.to_s
      }
    end

    return data
  end

  def self.order_details(order_code)
    @order = Order.find_by_code order_code, :include => {:batch => {:batch_hopper_lot => {:hopper_lot => {:hopper => {}, :lot=>{:ingredient=>{}}}}}, :recipe => {:ingredient_recipe => {:ingredient => {}}}, :medicament_recipe => {:ingredient_medicament_recipe => {:ingredient => {}}}, :product_lot => {:product => {}}, :client => {}}
    return nil if @order.nil?

    ingredients = {}
    @order.recipe.ingredient_recipe.each do |ir|
      ingredients[ir.ingredient.code] = ir.amount
    end
    unless @order.medicament_recipe.nil?
      @order.medicament_recipe.ingredient_medicament_recipe.each do |imr|
        ingredients[imr.ingredient.code] = imr.amount.to_f
      end
    end

    details = {}
    n_batch = @order.batch.count
    start_date = @order.batch.first.created_at
    end_date = @order.batch.last.created_at
    @order.batch.each do |batch|
      batch.batch_hopper_lot.each do |bhl|
        key = bhl.hopper_lot.lot.ingredient.code
        std_amount = (ingredients.has_key?(key)) ? ingredients[key] * n_batch : 0
        hopper_name = bhl.hopper_lot.hopper.name.present? ? bhl.hopper_lot.hopper.name : bhl.hopper_lot.hopper.number
        unless details.has_key?(key)
          details[key] = {
            'ingredient' => bhl.hopper_lot.lot.ingredient.name,
            'lot' => bhl.hopper_lot.lot.code,
            'hopper' => hopper_name,
            'real_kg' => bhl.amount.to_f,
            'std_kg' => std_amount.round(2),
            'var_kg' => 0,
            'var_perc' => 0,
          }
        else
          details[key]['real_kg'] += bhl.amount.to_f
        end
        details[key]['real_kg'] = details[key]['real_kg'].round(2)
        details[key]['var_kg'] = details[key]['real_kg'] - details[key]['std_kg']
        details[key]['var_perc'] = details[key]['var_kg'] * 100 / details[key]['std_kg']
      end
    end

    #Add recipe ingredients without any consumption in the order
    ingredients.each do |key, value|
      unless details.has_key?(key)
        std_amount = value * n_batch
        details[key] = {
          'ingredient' => Ingredient.find_by_code(key).name,
          'lot' => "N/A",
          'hopper' => "N/A",
          'real_kg' => 0,
          'std_kg' => std_amount,
          'var_kg' => std_amount,
          'var_perc' => 100,
        }
      end
    end
    
    total_std = 0
    total_real = 0
    
    details.each do |key, value|
      total_std += value['std_kg']
      total_real += value['real_kg']
    end

    total_std = total_std.round(2)
    total_real = total_real.round(2)

    total_var = total_real - total_std
    total_var_perc = total_var * 100 / total_std

    data = self.initialize_data('Detalle de Orden de Produccion')
    data['id'] = @order.id
    data['order'] = @order.code
    data['client'] = "#{@order.client.code} - #{@order.client.name}"
    data['recipe_id'] = @order.recipe.id
    data['recipe'] = "#{@order.recipe.code} - #{@order.recipe.name}"
    data['version'] = @order.recipe.version
    data['comment'] = @order.comment
    data['product'] = @order.product_lot.nil? ? "" : "#{@order.product_lot.product.code} - #{@order.product_lot.product.name}"
    data['start_date'] = @order.calculate_start_date()
    data['end_date'] = @order.calculate_end_date()
    data['prog_batches'] = @order.prog_batches.to_s
    data['real_batches'] = n_batch.to_s
    data['total_std'] = total_std
    data['total_real'] = total_real
    data['total_var'] = total_var
    data['total_var_perc'] = total_var_perc
    data['product_total'] = "#{total_real} Kg"
    data['real_production'] = @order.real_production.present? ? "#{@order.real_production} Kg" : "" 
    data['repaired'] = @order.repaired ? "Si" : "No"
    data['results'] = []

    details.sort_by {|k,v| k}.map do |key, value|
      element = {'code' => key}
      data['results'] << element.merge(value)
    end
    return data
  end

  def self.batch_details(order_code, batch_number)
    order = Order.find_by_code(order_code)
    return nil if order.nil?

    batch = Batch.find :first, :include => {:order => {:recipe => {:ingredient_recipe => {:ingredient => {}}}, :medicament_recipe => {:ingredient_medicament_recipe => {:ingredient =>{}}}}}, :conditions => {:number => batch_number, :orders => {:code => order_code}}
    return nil if batch.nil?

    data = self.initialize_data('Detalle de Batch')
    data['order'] = order_code
    data['recipe'] = "#{batch.order.recipe.code} - #{batch.order.recipe.name}"
    data['batch'] = batch_number
    data['start_date'] = batch.calculate_start_date
    data['end_date'] = batch.calculate_end_date
    data['results'] = []

    batch_hopper_lots = BatchHopperLot.find :all, :include => {:hopper_lot => {:hopper => {}, :lot => {:ingredient => {}}}}, :conditions => {:batch_id => batch.id}, :order=>['ingredients.code ASC']

    ingredients = {}
    batch.order.recipe.ingredient_recipe.each do |ir|
      ingredients[ir.ingredient.code] = ir.amount
    end

    unless batch.order.medicament_recipe.nil?
      batch.order.medicament_recipe.ingredient_medicament_recipe.each do |imr|
        ingredients[imr.ingredient.code] = imr.amount
      end
    end

    batch_hopper_lots.each do |bhl|
      real_kg = bhl.amount.to_f
      std_kg = 0
      var_kg = 0
      var_perc = 0
      if ingredients.has_key?(bhl.hopper_lot.lot.ingredient.code)
        std_kg = ingredients[bhl.hopper_lot.lot.ingredient.code]
        var_kg = real_kg - std_kg
        var_perc = var_kg * 100 / std_kg rescue 0
      end

      hopper_name = bhl.hopper_lot.hopper.name.present? ? bhl.hopper_lot.hopper.name : bhl.hopper_lot.hopper.number
      data['results'] << {
        'code' => bhl.hopper_lot.lot.ingredient.code,
        'ingredient' => bhl.hopper_lot.lot.ingredient.name,
        'real_kg' => real_kg,
        'std_kg' => std_kg,
        'var_kg' => var_kg,
        'var_perc' => var_perc,
        'hopper' => hopper_name,
        'lot' => bhl.hopper_lot.lot.code,
      }
    end

    return data
  end

  def self.consumption_per_recipe(start_date, end_date, recipe_code, recipe_version)
    recipe = Recipe.find :first, :include=>{:ingredient_recipe=>{:ingredient=>{}}}, :conditions => ['recipes.code = ? and recipes.version = ?', recipe_code, recipe_version]
    return nil if recipe.nil?

    std = {}
    real = {}
    nominal = {}

    data = self.initialize_data('Consumo por Receta')
    data['recipe'] = "#{recipe.code} - #{recipe.name}"
    data['version'] = recipe.version
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    recipe.ingredient_recipe.each do |ir|
      key = ir.ingredient.code
      nominal[key] = [ir.ingredient.name, ir.amount]
    end

    orders = Order.find :all, :include=>{:batch=>{:batch_hopper_lot=>{:hopper_lot=>{:lot=>{:ingredient=>{}}}}}}, :conditions => ["batches.start_date >= ? AND batches.end_date <= ? AND recipe_id = ?", self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), recipe.id], :order=>['batches.start_date DESC']

    orders.each do |o|
      o.batch.each do |b|
        b.batch_hopper_lot.each do |bhl|
          key = bhl.hopper_lot.lot.ingredient.code
          value = bhl.amount
          if nominal[key].nil?
            next
          end
          std[key] = std.fetch(key, 0) + nominal[key][1]
          real[key] = real.fetch(key, 0) + value
        end
      end
    end
    nominal.sort_by {|k,v| k}.map do |key, value|
      data['results'] << {
        'code' => key,
        'ingredient' => value[0],
        'std_kg' => std[key].to_s,
        'real_kg' => real[key].to_s,
      }
    end

    return data
  end

  def self.consumption_per_selected_ingredients(start_date, end_date, ingredients_codes)
    data = self.initialize_data('Consumo por Ingrediente')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    results = {}
    batches = Batch.find :all, :include => {:batch_hopper_lot => {:hopper_lot => {:lot => {:ingredient => {}}}}, :order => {:recipe => {:ingredient_recipe => {}}, :medicament_recipe => {:ingredient_medicament_recipe => {}}}}, :conditions => ['start_date >= ? AND end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)]
    
    batches.each do |batch|
      batch.batch_hopper_lot.each do |bhl|
        unless ingredients_codes.include? bhl.hopper_lot.lot.ingredient.code 
          next
        end
        real_kg = bhl.amount.to_f
        std_kg = -1
        batch.order.recipe.ingredient_recipe.each do |ir|
          if ir.ingredient.id == bhl.hopper_lot.lot.ingredient.id
            std_kg = ir.amount.to_f
            break
          end
        end
        unless batch.order.medicament_recipe.nil?
          batch.order.medicament_recipe.ingredient_medicament_recipe.each do |imr|
            if imr.ingredient.id == bhl.hopper_lot.lot.ingredient.id
              std_kg = imr.amount.to_f
              break
            end
          end
        end

        key = bhl.hopper_lot.lot.code
        if results.has_key?(key)
          results[key]['real_kg'] += real_kg
          results[key]['std_kg'] += std_kg
          results[key]['var_kg'] = results[key]['real_kg'] - results[key]['std_kg']
          results[key]['var_perc'] = results[key]['var_kg'] * 100 / results[key]['std_kg']
        else
          var_kg = real_kg - std_kg
          var_perc = var_kg * 100 / std_kg
          results[key] = {
            'lot' => key,
            'ingredient_code' => bhl.hopper_lot.lot.ingredient.code,
            'ingredient_name' => bhl.hopper_lot.lot.ingredient.name,
            'real_kg' => real_kg,
            'std_kg' => std_kg,
            'var_kg' => var_kg,
            'var_perc' => var_perc
          }
        end
      end
    end
    results.sort_by {|k,v| v['ingredient_code']}.map do |key, item|
      data['results'] << item
    end

    return data
  end

  def self.consumption_per_ingredients(start_date, end_date)
    data = self.initialize_data('Consumo por Ingrediente')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    results = {}
    batches = Batch.find :all, :include => {:batch_hopper_lot => {:hopper_lot => {:lot => {:ingredient => {}}}}, :order => {:recipe => {:ingredient_recipe => {}}, :medicament_recipe => {:ingredient_medicament_recipe => {}}}}, :conditions => ['start_date >= ? AND end_date <= ?', self.start_date_to_sql(start_date), self.end_date_to_sql(end_date)]

    batches.each do |batch|
      batch.batch_hopper_lot.each do |bhl|
        real_kg = bhl.amount.to_f
        std_kg = -1
        batch.order.recipe.ingredient_recipe.each do |ir|
          if ir.ingredient.id == bhl.hopper_lot.lot.ingredient.id
            std_kg = ir.amount.to_f
            break
          end
        end
        unless batch.order.medicament_recipe.nil?
          batch.order.medicament_recipe.ingredient_medicament_recipe.each do |imr|
            if imr.ingredient.id == bhl.hopper_lot.lot.ingredient.id
              std_kg = imr.amount.to_f
              break
            end
          end
        end

        key = bhl.hopper_lot.lot.code
        if results.has_key?(key)
          results[key]['real_kg'] += real_kg
          results[key]['std_kg'] += std_kg
          results[key]['var_kg'] = results[key]['real_kg'] - results[key]['std_kg']
          results[key]['var_perc'] = results[key]['var_kg'] * 100 / results[key]['std_kg']
        else
          var_kg = real_kg - std_kg
          var_perc = var_kg * 100 / std_kg
          results[key] = {
            'lot' => key,
            'ingredient_code' => bhl.hopper_lot.lot.ingredient.code,
            'ingredient_name' => bhl.hopper_lot.lot.ingredient.name,
            'real_kg' => real_kg,
            'std_kg' => std_kg,
            'var_kg' => var_kg,
            'var_perc' => var_perc
          }
        end
      end
    end

    results.sort_by {|k,v| v['ingredient_code']}.map do |key, item|
      data['results'] << item
    end

    return data
  end

  def self.consumption_per_client(start_date, end_date, client_id)
    client = Client.find(client_id)

    data = self.initialize_data('Consumo por Cliente')
    data['client'] = "#{client.code} - #{client.name}"
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    real = {}
    name = {}
    orders = Order.find :all, :include=>{:batch=>{:batch_hopper_lot=>{:hopper_lot=>{:lot=>{:ingredient=>{}}}}}}, :conditions => ["batches.start_date >= ? AND batches.end_date <= ? AND orders.client_id = ?", self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), client.id], :order=>['batches.start_date DESC']

    orders.each do |o|
      o.batch.each do |b|
        b.batch_hopper_lot.each do |bhl|
          key = bhl.hopper_lot.lot.ingredient.code
          name[key] = bhl.hopper_lot.lot.ingredient.name
          real[key] = real.fetch(key, 0) + bhl.amount
        end
      end
    end
    real.sort_by {|k,v| k}.map do |key, value|
      data['results'] << {
        'code' => key,
        'ingredient' => name[key],
        'real_kg' => value.to_s,
      }
    end

    return data
  end

  def self.stock_adjustments(start_date, end_date)
    transaction_types = TransactionType.find :all
    adjustment_type_ids = []
    transaction_types.each do |ttype|
      unless ttype.code.match(/(?i)AJU/).nil?
        puts "Adjusment code found: " + ttype.code
        adjustment_type_ids << ttype.id
      end
    end
    return nil if adjustment_type_ids.length.zero?

    adjustments = Transaction.find :all, :conditions => {:transaction_type_id => adjustment_type_ids, :date => (start_date)..((end_date) + 1.day)}, :order=>['date DESC']
    return nil if adjustments.length.zero?

    data = self.initialize_data('Ajustes de Existencias')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    adjustments.each do |a|
      lot = a.get_lot
      lot_code = lot.code
      content_code = ''
      content_name = ''
      if a.content_type == 1 # content = lot 
        content_code = lot.ingredient.code
        content_name = lot.ingredient.name
      else # content = product lot
        content_code = lot.product.code
        content_name = lot.product.name
      end
      transaction_type_id = a.transaction_type_id
      sign = TransactionType.find(transaction_type_id).sign
      ttype_code = TransactionType.find(transaction_type_id).code
      amount = a.amount
      if sign == '-'
        amount = -1 * amount
      end

      data['results'] << {
        'lot_code' => lot_code,
        'content_code' => content_code,
        'content_name' => content_name,
        'amount' => amount.to_s,
        'user_name' => a.user.login,
        'comment' => a.comment,
        'date' => self.print_formatted_date(a.date),
        'adjustment_code' => ttype_code
      }
    end

    return data
  end

  def self.lots_incomes(start_date, end_date)
    income_type = TransactionType.find :first, :conditions => {:code => 'EN-COM'}
    "Income code found: " + income_type.code
    return nil if income_type.nil?

    incomes = Transaction.find :all, :conditions => {:transaction_type_id => income_type, :date => (start_date)..((end_date) + 1.day)}, :order=>['date DESC']
    return nil if incomes.length.zero?

    data = self.initialize_data('Entradas de Materia Prima')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    incomes.each do |i|
      lot = i.get_lot
      lot_code = lot.code
      content_code = ''
      content_name = ''
      if i.content_type == 1
        content_code = lot.ingredient.code
        content_name = lot.ingredient.name
        transaction_type_id = i.transaction_type_id
        sign = TransactionType.find(transaction_type_id).sign
        ttype_code = TransactionType.find(transaction_type_id).code
        amount = i.amount
        if sign == '-'
          amount = -1 * amount
        end

        data['results'] << {
          'lot_code' => lot_code,
          'content_code' => content_code,
          'content_name' => content_name,
          'amount' => amount.to_s,
          'user_name' => i.user.login,
          'date' => self.print_formatted_date(i.date)
        }
      end
    end

    return data
  end

  def self.simple_stock_per_lot(content_type, factory_id, date)
    title = (content_type == 1) ? 'Existencias de Materia Prima por lotes' : 'Existencias de Producto Terminado por lotes'
    data = self.initialize_data(title)
    data['date'] = self.print_range_date(date)
    data['results'] = []

    lots = []
    if content_type == 1
      lots = Lot.order('code asc')
	  lots = lots.where(:active => true)
	  lots = lots.where(:client_id => factory_id) if factory_id != 0
    else
      lots = ProductLot.order('code asc')
	  lots = lots.where(:active => true)
	  lots = lots.where(:client_id => factory_id) if factory_id != 0
    end
    lots.each do |lot|
      transaction = Transaction.first :conditions => ['content_type = ? and content_id = ? and created_at < ?', content_type, lot.id, end_date_to_sql(date)], :order => ['created_at desc']
      if transaction
        data['results'] << {
          'code' => lot.code,
          'name' => lot.get_content.name,
          'stock' => transaction.stock_after
        }
      else
        data['results'] << {
          'code' => lot.code,
          'name' => lot.get_content.name,
          'stock' => 0
        }
      end
    end

    data['results'].sort! {|a,b| a['code'] <=> b['code']}
    return data
  end

  def self.simple_stock(content_type, factory_id, date)
    title = (content_type == 1) ? 'Existencias de Materia Prima' : 'Existencias de Producto Terminado'
    data = self.initialize_data(title)
    data['date'] = self.print_range_date(date)
    data['results'] = []

    results = {}

    lots = []
    if content_type == 1
      lots = Lot.order('code asc')
      lots = lots.where(:active => true)
      lots = lots.where(:client_id => factory_id) if factory_id != 0
    else
      lots = ProductLot.order('code asc')
      lots = lots.where(:active => true)
      lots = lots.where(:client_id => factory_id) if factory_id != 0
    end

    return nil if lots.empty?

    lots.each do |l|
      key = l.get_content.code
      transaction = Transaction.first :conditions => ['content_type = ? and content_id = ? and created_at < ?', content_type, l.id, end_date_to_sql(date)], :order => ['created_at desc']
      if transaction
        if results.has_key?(key)
          results[key]['stock'] += transaction.stock_after
        else
          results[key] = {
            'code' => key,
            'name' => l.get_content.name,
            'stock' => transaction.stock_after
          }
        end
      else
        results[key] = {
          'code' => key,
          'name' => l.get_content.name,
          'stock' => 0
        }
      end
    end
    results.sort_by {|k,v| k}.map do |key, item|
      data['results'] << item
    end
    return data
  end

  def self.simple_stock_projection(factory_id, days)
    days = days.to_i
    return nil if days <= 0

    data = self.initialize_data("Proyeccion de Materia Prima")
    data['date'] = self.print_range_date(Date.today)
    data['days'] = days.to_s
    data['results'] = []

    today = Date.today
    lots = Lot.includes(:ingredient).order('ingredients.code ASC').where(:active => true)
    lots = lots.where(:client_id => factory_id) if factory_id != 0

    orders = Order.includes({:batch => {:batch_hopper_lot => {:hopper_lot => {:lot => {}}}}})
    orders = orders.where(:created_at => ((today - days)..(today)))
    orders = orders.where(:client_id => factory_id) if factory_id != 0

    return nil, nil if orders.empty?

    consumptions = {}
    orders.each do |order|
      order.batch.each do |batch|
        batch.batch_hopper_lot.each do |bhl|
          key = bhl.hopper_lot.lot.ingredient_id
          if consumptions.has_key? key
            consumptions[key] += bhl.amount
          elsif bhl.amount > 0
            consumptions[key] = bhl.amount
          end
        end
      end
    end

    stocks = {}
    lots.each do |lot|
      key = lot.ingredient_id
      if stocks.has_key? key
        stocks[key]['stock'] += lot.stock
      else
        stocks[key] = {
          'code' => lot.ingredient.code, 
          'name' => lot.ingredient.name,
          'stock' => lot.stock,
          'projection' => "N/A"
        }
      end
    end

    consumptions.each do |key, amount|
      if stocks.has_key? key
        stocks[key]['projection'] = (stocks[key]['stock'] / (amount / days)).to_i
      end
    end

    stocks.each do |key, item|
      data['results'] << item
    end
    return data
  end

  def self.product_lots_dispatches(start_date, end_date, doc_number)
    if doc_number.blank?
      conditions = {:transaction_type_id=>5, :date=>(start_date)..((end_date) + 1.day)}
    else
      conditions = {:transaction_type_id=>5, :transactions=>{:document_number=>doc_number}, :date=>(start_date)..((end_date) + 1.day)}
    end

    dispatches = Transaction.find :all, :conditions => conditions, :order=>['date DESC']
    return nil if dispatches.length.zero?

    data = self.initialize_data('Despacho de producto terminado')
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    dispatches.each do |d|
      if d.content_type == 2
        product_lot = d.get_lot

        data['results'] << {
          'lot_code' => product_lot.code,
          'doc_number' => d.document_number || '--',
          'content_code' => product_lot.product.code,
          'content_name' => product_lot.product.name,
          'amount' => d.amount.to_s,
          'user_name' => d.user.login,
          'comment' => d.comment,
          'date' => self.print_formatted_date(d.date),
          'adjusment_code' => d.transaction_type.code,
        }
      end
    end
    return nil if data['results'].empty?
    return data
  end

  def self.production_per_recipe(start_date, end_date, recipe_code, recipe_version)
    recipe = Recipe.find :first, :include=>{:ingredient_recipe=>{:ingredient=>{}}}, :conditions => ['code = ? and version = ?', recipe_code, recipe_version], :order => ['id desc']
    return nil if recipe.nil?

    data = self.initialize_data('Produccion por Receta')
    data['recipe'] = "#{recipe.code} - #{recipe.name}"
    data['version'] = recipe.version
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    ingredients = []
    nominal = 0
    recipe.ingredient_recipe.each do |ir|
      ingredients << ir.ingredient.id
      nominal += ir.amount
    end

    orders = Order.find :all, :include=>{:batch=>{:batch_hopper_lot=>{:hopper_lot=>{:lot=>{}}}}, :client=>{}}, :conditions => ["batches.start_date >= ? AND batches.end_date <= ? AND recipe_id = ?", self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), recipe.id], :order=>['batches.start_date DESC']
    return nil if orders.empty?

    orders.each do |o|
      std = 0
      real = 0
      o.batch.each do |b|
        std += nominal
        b.batch_hopper_lot.each do |bhl|
          if ingredients.include? bhl.hopper_lot.lot.ingredient_id
            real += bhl.amount
          end
        end
      end

      data['results'] << {
        'order' => o.code,
        'client_code' => o.client.ci_rif,
        'client_name' => o.client.name,
        'real_batches' => o.get_real_batches(),
        'std_kg' => std.to_s,
        'real_kg' => real.to_s,
      }
    end

    return data
  end

  def self.production_per_client(start_date, end_date, client_id)
    client = Client.find client_id rescue nil
    return nil if client.nil?

    data = self.initialize_data('Produccion por Cliente')
    data['client'] = "#{client.ci_rif} - #{client.name}"
    data['since'] = self.print_range_date(start_date)
    data['until'] = self.print_range_date(end_date)
    data['results'] = []

    orders = Order.find :all, :include=>{:batch=>{:batch_hopper_lot=>{:hopper_lot=>{:lot=>{:ingredient=>{}}}}}, :recipe=>{:ingredient_recipe=>{:ingredient=>{}}}, :medicament_recipe => {:ingredient_medicament_recipe => {:ingredient => {}}}}, :conditions => ["batches.start_date >= ? AND batches.end_date <= ? AND orders.client_id = ?", self.start_date_to_sql(start_date), self.end_date_to_sql(end_date), client.id], :order=>['batches.start_date DESC']

    orders.each do |o|
      std = 0
      real = 0
      nominal = 0

      o.recipe.ingredient_recipe.each do |ir|
        nominal += ir.amount
      end
      unless o.medicament_recipe.nil?
        o.medicament_recipe.ingredient_medicament_recipe.each do |imr|
          nominal += imr.amount
        end
      end

      o.batch.each do |b|
        std += nominal
        b.batch_hopper_lot.each do |bhl|
          real += bhl.amount
        end
      end

      data['results'] << {
        'order' => o.code,
        'recipe_code' => o.recipe.code,
        'recipe_name' => o.recipe.name,
        'real_batches' => o.get_real_batches(),
        'std_kg' => std.to_s,
        'real_kg' => real.to_s,
      }
    end

    return data
  end

  # ================================================================
  # Utilities
  # ================================================================

  def self.param_to_date(param, name)
    year = param["#{name}(1i)"].to_i
    month = param["#{name}(2i)"].to_i
    day = param["#{name}(3i)"].to_i
    return Date.new(year, month, day)
  end

  def self.param_to_datetime(param, name)
    year = param["#{name}(1i)"].to_i
    month = param["#{name}(2i)"].to_i
    day = param["#{name}(3i)"].to_i
    hour = param["#{name}(4i)"].to_i
    min = param["#{name}(5i)"].to_i
    return Time.new(year, month, day, hour, min)
  end

  def self.print_formatted_date(date)
    date.strftime("%d/%m/%Y")
  end

  def self.start_date_to_sql(date)
    date.strftime("%Y-%m-%d")
  end

  def self.end_date_to_sql(date)
    (date + 1.day).strftime("%Y-%m-%d")
  end

  def self.print_range_date(str_date, with_time=false)
    fmt = with_time ? "%d/%m/%Y %H:%M:%S" : "%d/%m/%Y"
    return str_date.strftime(fmt)
  end

  def self.int_seconds_to_time_string(seconds)
    if seconds < 3600
      return Time.at(seconds).gmtime.strftime('%Mm%Ss')
    else
      return Time.at(seconds).gmtime.strftime('%Hh%Mm:%Ss')
    end
  end

  private

  def self.initialize_data(title)
    company = YAML::load(File.open("#{Rails.root.to_s}/config/global.yml"))['application']
    puts company.inspect
    data = {}
    data['title'] = title
    data['company_name'] = company['name']
    data['company_address'] = company['address']
    data['company_rif'] = company['rif']
    data['company_logo'] = company['logo']
    data['footer'] = company['footer']

    return data
  end
end
