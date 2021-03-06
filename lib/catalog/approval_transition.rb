module Catalog
  class ApprovalTransition
    attr_reader :order_item_id, :order_item, :state

    def initialize(order_item_id)
      @order_item = OrderItem.find(order_item_id)
      @approvals = @order_item.approval_requests
    end

    def process
      state_transitions
      self
    end

    private

    def state_transitions
      if approved?
        @state = "Approved"
        submit_order
      elsif denied?
        @state = "Denied"
        mark_denied
      elsif canceled?
        @state = "Canceled"
        mark_canceled
      elsif error?
        @state = "Failed"
        mark_errored
      else
        @state = "Pending"
        ::Catalog::OrderStateTransition.new(@order_item.order).process
      end
    end

    def submit_order
      finalize_order
      @order_item.order.update_message("info", "Submitting Order for provisioning")
      Catalog::SubmitNextOrderItem.new(@order_item.order_id).process
    rescue ::Catalog::TopologyError => e
      Rails.logger.error("Error Submitting Order #{@order_item.order_id}, #{e.message}")
      @order_item.order.update_message("error", "Error when submitting order item #{@order_item.id}: #{e.message}")
    end

    def mark_canceled
      finalize_order
      @order_item.order.update_message("info", "Order has been canceled")
      Rails.logger.info("Order #{@order_item.order_id} has been canceled")
    end

    def mark_denied
      finalize_order
      @order_item.order.update_message("info", "Order has been denied")
      Rails.logger.info("Order #{@order_item.order_id} has been denied")
    end

    def mark_errored
      finalize_order
      @order_item.order.update_message("error", "Order has approval errors. #{reasons}")
      Rails.logger.error("Order #{@order_item.order_id} has failed. #{reasons}")
    end

    def finalize_order
      @order_item.update(:state => @state)
      Catalog::OrderStateTransition.new(@order_item.order).process
    end

    def approved?
      @approvals.present? && @approvals.all? { |req| req.state == "approved" }
    end

    def denied?
      @approvals.present? && @approvals.any? { |req| req.state == "denied" }
    end

    def canceled?
      @approvals.present? && @approvals.any? { |req| req.state == "canceled" }
    end

    def error?
      @approvals.present? && @approvals.any? { |req| req.state == "error" }
    end

    def reasons
      return "" if @approvals.blank?

      @approvals.collect(&:reason).compact.join('. ')
    end
  end
end
