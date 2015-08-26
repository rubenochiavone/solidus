# Implementation class for Cancan gem.  Instead of overriding this class, consider adding new permissions
# using the special +register_ability+ method which allows extensions to add their own abilities.
#
# See http://github.com/ryanb/cancan for more details on cancan.
require 'cancan'
module Spree
  class Ability
    include CanCan::Ability

    class_attribute :abilities
    self.abilities = Set.new

    attr_reader :user

    # Allows us to go beyond the standard cancan initialize method which makes it difficult for engines to
    # modify the default +Ability+ of an application.  The +ability+ argument must be a class that includes
    # the +CanCan::Ability+ module.  The registered ability should behave properly as a stand-alone class
    # and therefore should be easy to test in isolation.
    def self.register_ability(ability)
      self.abilities.add(ability)
    end

    def self.remove_ability(ability)
      self.abilities.delete(ability)
    end

    def initialize(current_user)
      @user = current_user || Spree.user_class.new

      alias_actions
      grant_default_permissions
      activate_permission_sets
      register_extension_abilities
    end

    private

    def alias_actions
      clear_aliased_actions

      # override cancan default aliasing (we don't want to differentiate between read and index)
      alias_action :delete, to: :destroy
      alias_action :edit, to: :update
      alias_action :new, to: :create
      alias_action :new_action, to: :create
      alias_action :show, to: :read
      alias_action :index, :read, to: :display
    end

    def grant_default_permissions
      # if the user is a "super user" give them full permissions, otherwise give them the permissions
      # required to checkout and use the frontend.
      if user.respond_to?(:has_spree_role?) && user.has_spree_role?('admin')
        can :manage, :all
      else
        grant_generic_user_permissions
      end
    end

    def grant_generic_user_permissions
      can :display, Country
      can :display, OptionType
      can :display, OptionValue
      can :create, Order
      can [:read, :update], Order do |order, token|
        order.user == user || order.guest_token && token == order.guest_token
      end
      can :create, ReturnAuthorization do |return_authorization|
        return_authorization.order.user == user
      end
      can [:display, :update], CreditCard, user_id: user.id
      can :display, Product
      can :display, ProductProperty
      can :display, Property
      can :create, Spree.user_class
      can [:read, :update], Spree.user_class, id: user.id
      can :display, State
      can :display, StockItem, stock_location: { active: true }
      can :display, StockLocation, active: true
      can :display, Taxon
      can :display, Taxonomy
      can [:display, :view_out_of_stock], Variant
      can :display, Zone
    end

    # Before, this was the only way to extend this ability. Permission sets have been added since.
    # It is recommended to use them instead for extension purposes if possible.
    def register_extension_abilities
      Ability.abilities.each do |clazz|
        ability = clazz.send(:new, user)
        @rules = rules + ability.send(:rules)
      end
    end

    def activate_permission_sets
      Spree::RoleConfiguration.instance.activate_permissions! self, user
    end
  end
end
