require 'active_support'

module Machinist
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def blueprints
      @blueprints ||= {}
    end
    
    def blueprint(name=nil,&blueprint)
      name ||= '__default__'
      blueprints[name] = blueprint
    end
  
    def make(*args)
      attributes = Hash === args.last ? args.pop : {}
      name = args.shift || '__default__'
      blueprint = blueprints[name]
      
      raise "No blueprint '#{name}' for class #{self}" unless blueprint
      
      lathe = Lathe.new(self.new, attributes)
      lathe.instance_eval(&blueprint)
      lathe.object.save!
      
      returning(lathe.object.reload) do |object|
        yield object if block_given?
      end
    end
  end
  
  class Lathe
    def initialize(object, attributes)
      @object = object
      @assigned_attributes = []
      attributes.each do |key, value|
        @object.send("#{key}=", value)
        @assigned_attributes << key
      end
    end

    attr_reader :object

    def method_missing(symbol, *args, &block)
      if @assigned_attributes.include?(symbol)
        @object.send(symbol)
      else
        value = if block
          block.call
        elsif args.first.is_a?(Hash) || args.empty?
          symbol.to_s.camelize.constantize.make(args.first || {})
        else
          args.first
        end
        @object.send("#{symbol}=", value)
        @assigned_attributes << symbol
      end
    end
  end
end
