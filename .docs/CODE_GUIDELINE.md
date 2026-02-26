# Convention over Configuration
Rails' productivity lever: thousands of mundane decisions made for you. Don't bike-shed primary key names or file locations. Conventions create shared vocabulary and enable deeper abstractions. Person → people table → has_many :people → Person class.

# Exalt beautiful code
Code is literature. Prioritize readability and aesthetics alongside functionality. Beautiful code should flow like natural language and reveal intention. The Inflector exists to make Person → people because it's more beautiful than manual configuration.

# Focus on subject: person vs collection
person.in?(people)  vs people.include?(person)

# Push up a big tent
No ideological purity tests. RSpec thrives despite DHH's preference for Minitest. API-only Rails serves SPA developers. Diversity of thought strengthens the commons. Lower barriers: typo fixes can lead to major contributions.

# Tell, Don't Ask (Rails Examples)
```ruby
# ✅ Encapsulate business logic in model methods
user.upgrade_to_premium!
campaign.launch_with_notifications!
order.process_payment!

# ❌ Controller/service doing model's job
if user.qualifying_orders.sum(:total) > User::PREMIUM_THRESHOLD
  user.update!(premium: true)
  UserMailer.premium_welcome(user).deliver_now
end

# ✅ Model encapsulates the logic
class User < ApplicationRecord
  def upgrade_to_premium!
    return false unless qualifies_for_premium?
    update!(premium: true)
    UserMailer.premium_welcome(self).deliver_now
    true
  end

  private

  def qualifies_for_premium?
    qualifying_orders.sum(:total) >= PREMIUM_THRESHOLD
  end
end
```

# Law of Demeter (Rails Delegation)
```ruby
# ✅ Delegate to avoid chain drilling
class Order < ApplicationRecord
  delegate :full_name, :email, to: :customer, prefix: true
  delegate :domestic?, to: :shipping_address
end

order.customer_full_name    # ✅ Clean interface
order.domestic?             # ✅ Domain-focused

# ❌ Violates Law of Demeter
order.customer.address.country.domestic?

# ✅ ActiveRecord includes for avoiding N+1
orders = Order.includes(customer: :profile).recent
```
# Single Responsibility Principle

**Apply SRP at two levels: class level (services) and method level (private helpers).**

### Class-Level SRP (Services)
Extract to a new service class when you have multi-model coordination or complex workflows.

```ruby
# ✅ Each service has one clear purpose
class Campaigns::LaunchService
  def initialize(campaign:, launched_by:)
    @campaign, @launched_by = campaign, launched_by
  end

  def call
    validate_launch_requirements!
    update_campaign_status!
    send_launch_notifications!
    track_launch_event!
  end
end

# ❌ God service doing everything
class CampaignService
  def launch(campaign)      # Too many responsibilities
  def send_emails(campaign)
  def process_analytics(campaign)
end
```

## Method-Level SRP (Private Helpers)
*Keep it in the same class.* Extract private helper methods to keep each method ≤5 lines and doing one thing.

```ruby
# ❌ Fat method violating SRP - doing query, logic, updates, and notifications
def process_order_items
  @order.line_items.includes(:product, :inventory).each do |item|
    inventory_item = item.product.inventory_items.find_by(warehouse_id: @warehouse.id)
    if inventory_item && inventory_item.quantity >= item.quantity
      inventory_item.update!(quantity: inventory_item.quantity - item.quantity)
      OrderLog.create!(order: @order, item: item, action: 'fulfilled')
    else
      item.update!(status: 'backorder')
      NotificationService.notify_backorder(item)
    end
  end
end

# ✅ SRP at method level - each method has ONE responsibility
def process_order_items
  order_items.each do |item|
    inventory = find_inventory_for(item)
    process_fulfillment(item, inventory)
  end
end

private

def order_items                            # Responsibility: Query collection
  @order.line_items.includes(:product, :inventory)
end

def find_inventory_for(item)              # Responsibility: Find inventory
  item.product.inventory_items.find_by(warehouse_id: @warehouse.id)
end

def process_fulfillment(item, inventory)  # Responsibility: Route logic
  sufficient_inventory?(item, inventory) ? fulfill_item(item, inventory) : backorder_item(item)
end

def sufficient_inventory?(item, inventory) # Responsibility: Check condition
  inventory && inventory.quantity >= item.quantity
end

def fulfill_item(item, inventory)         # Responsibility: Fulfill
  inventory.update!(quantity: inventory.quantity - item.quantity)
  OrderLog.create!(order: @order, item: item, action: 'fulfilled')
end

def backorder_item(item)                  # Responsibility: Backorder
  item.update!(status: 'backorder')
  NotificationService.notify_backorder(item)
end
```

*When to use method-level SRP (stay in same class):*
- ✅ Single model/domain operations
- ✅ Simple coordination within one context
- ✅ Helper methods improve readability
- ✅ No external dependencies to mock

*When to extract to new class/service:*
- ❌ Multi-model coordination across domains
- ❌ Complex business workflows spanning multiple contexts
- ❌ Multiple external service dependencies
- ❌ Reusable logic needed across multiple classes

# Composition > Inheritance (Rails Concerns)
```ruby
# ✅ Compose behavior with concerns
class Campaign < ApplicationRecord
  include Trackable      # Analytics behavior
  include Notifiable     # Email behavior
  include Schedulable    # Background job behavior

  belongs_to :company
end

class User < ApplicationRecord
  include Trackable      # Same analytics behavior
  include Notifiable     # Same email behavior
  # Not schedulable - doesn't need that behavior
end

# ✅ Concerns provide shared behavior without inheritance
module Trackable
  extend ActiveSupport::Concern

  included do
    has_many :analytics_events, as: :trackable
  end

  def track_event(name, properties = {})
    analytics_events.create!(name: name, properties: properties)
  end
end

# ❌ Deep inheritance hierarchy
class Campaign < MarketingAsset < TrackableAsset < ApplicationRecord
  # Hard to understand, tight coupling
end
```

# Duck Typing (Rails Polymorphism)
```ruby
# ✅ Polymorphic associations use duck typing
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true  # Works with any commentable
end

class Post < ApplicationRecord
  has_many :comments, as: :commentable
end

class Campaign < ApplicationRecord
  has_many :comments, as: :commentable
end

# Both respond to comments interface - duck typing in action

# ✅ Service objects with duck typing
class NotificationService
  def send_notification(recipient:, message:)
    # Works with any recipient that responds to notify!
    recipient.notify!(message)
  end
end

# Both respond to notify! - duck typed
class User < ApplicationRecord
  def notify!(message)
    UserMailer.notification(self, message).deliver_now
  end
end

class AdminUser < ApplicationRecord
  def notify!(message)
    SlackNotifier.send(message, channel: '#admin')
  end
end

# ❌ Type checking instead of duck typing
if recipient.is_a?(User)
  UserMailer.notification(recipient, message).deliver_now
elsif recipient.is_a?(AdminUser)
  SlackNotifier.send(message, channel: '#admin')
end
```

# Naming conventions:
- Namespace by domain: Campaigns::, Feedbacks::, TaxEngine::
- Action-focused names: SoftDeleter, Persister, LaunchService
- Use .call for simple actions, multiple methods for complex operations

# Testing Strategy
*Important*: Always use a subagent to run tests. Use the Task tool with subagent_type: "general-purpose" for any test execution. Never run tests directly in the main context window.

- Use database-backed tests with real ActiveRecord objects. 
- Only mock external services. Test behavior, not implementation.
- Request specs must implement rswag for api documentation

## Rswag
run after creating new request specs 
```bash
rake rswag:specs:swaggerize
```

# Database-Backed Testing Principles
ruby
# ✅ Use factories with real database constraints and precision
user = create(:user, email: "test@example.com")
order = create(:order, user: user, total: 100.50)
expect(order.total).to eq(100.50)  # DB decimal precision

# ✅ Mock external services only, never internal models
gateway = instance_double(StripeGateway, charge: success_response)
PaymentProcessor.new(gateway: gateway).process(order)
expect(gateway).to have_received(:charge).with(amount: 10050)

# ❌ Don't mock internal models - loses validation behavior
allow(Order).to receive(:create!).and_return(mock_order)

# Always Keyword Arguments
```ruby
def initialize(user:, company:, content: nil) # ✅
def initialize(user, company, content) # ❌
```

# Strong Parameters Only
```ruby
params.require(:campaign).permit(:name) # ✅
@campaign.update(params[:campaign]) # ❌
```

# Result Objects Not Exceptions
```ruby
Result = Struct.new(:success, :data, :error, keyword_init: true)
# Use for business logic outcomes
```

# Models: Data + Associations Only
```ruby
class Campaign < ApplicationRecord
  belongs_to :company
  def launch! = Campaigns::LaunchService.new(campaign: self).call
end
```

# Controllers: Authorize + Delegate
```ruby
def create
  authorize Campaign
  result = Service.new(attributes: params).call
  # Handle result
end
```

# Critical Don'ts
- No positional args, no direct params access, no OpenStruct
- No business logic in controllers, no memoized ENV vars
- Test behavior not implementation, use request specs over controller tests
- Don't over-extract to services: single model operations stay in models
- Methods should be ≤5 lines: extract private helpers for clarity, don't create new classes
- Don't write fat methods: apply SRP at method level by extracting private helpers