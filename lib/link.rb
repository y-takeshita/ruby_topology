# -*- coding: utf-8 -*-
require 'rubygems'
require 'pio/lldp'

#
# Edges between two switches.
#
class Link
  attr_reader :dpid_a
  attr_reader :dpid_b
  attr_reader :port_a
  attr_reader :port_b

  def initialize(dpid, packet_in)
    if !packet_in.ipv4? || (packet_in.ipv4_saddr.to_s == '0.0.0.0')
      lldp = Pio::Lldp.read(packet_in.data)
      setting lldp.dpid, dpid, lldp.port_number, packet_in.in_port
    else
      setting packet_in.ipv4_saddr, dpid, 1, packet_in.in_port
    end
  end

  def ==(other)
    (@dpid_a == other.dpid_a) &&
      (@dpid_b == other.dpid_b) &&
      (@port_a == other.port_a) &&
      (@port_b == other.port_b)
  end

  def <=>(other)
    to_s <=> other.to_s
  end

  def to_s
    format '%#x (port %d) <-> %#x (port %d)', dpid_a, port_a, dpid_b, port_b
  end

  def has?(dpid, port)
    ((@dpid_a == dpid) && (@port_a == port)) ||
      ((@dpid_b == dpid) && (@port_b == port))
  end

  private

  def setting(a, b, c, d)
    @dpid_a = a
    @dpid_b = b
    @port_a = c
    @port_b = d
  end
end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
