# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path(File.join File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'bundler/setup'

require 'command-line'
require 'topology'
require 'trema'
require 'trema-extensions/port'

#
require 'Dijkstra'
require 'set'
#
# This controller collects network topology information using LLDP.
#
class TopologyController < Controller
  periodic_timer_event :flood_lldp_frames, 1

  def start
    @command_line = CommandLine.new
    @command_line.parse(ARGV.dup)
    @topology = Topology.new(@command_line.view)
    #
    @dijkstra = Dijkstra.new

  end

  def switch_ready(dpid)
    send_message dpid, FeaturesRequest.new
  end

  def features_reply(dpid, features_reply)
    features_reply.physical_ports.select(&:up?).each do |each|
      @topology.add_port each
    end
  end

  def switch_disconnected(dpid)
    @topology.delete_switch dpid
  end

  def port_status(dpid, port_status)
    updated_port = port_status.port
    return if updated_port.local?
    @topology.update_port updated_port
  end

=begin
  def packet_in(dpid, packet_in)
    return unless packet_in.lldp?
    @topology.add_link_by dpid, packet_in
  end
=end

  def packet_in(dpid, packet_in)
   if packet_in.ipv4? && (packet_in.ipv4_saddr.to_s != "0.0.0.0")
     @topology.add_host dpid, packet_in

     de_sw = search_node packet_in.ipv4_daddr, @topology
     de_port = search_ip_port packet_in.ipv4_daddr, @topology

     path = @dijkstra.shortest_path dpid, packet_in, @topology
     if !(path == nil)
       send_flow_mod_add(
                         de_sw,
                         :match => Match.new(:dl_type => 0x800,
                                             :dl_dst => packet_in.macda,
                                             :nw_dst => packet_in.ipv4_daddr), 
                         :actions => Trema::SendOutPort.new(de_port))

       sw = de_sw
       while !(path[sw] == 0) do
         nxt = sw
         sw = path[sw]
         port = search_port sw, nxt, @topology 
         send_flow_mod_add(
                           sw,
                           :match => Match.new(:dl_type => 0x800,
                                               :dl_dst => packet_in.macda,
                                               :nw_dst => packet_in.ipv4_daddr), 
                           :actions => Trema::SendOutPort.new(port))
       end

       send_packet_out(
                       de_sw,
                       :packet_in => packet_in,
                       :actions => Trema::SendOutPort.new(de_port))
     end

   end
    @topology.add_link_by dpid, packet_in
  end

  private

  def flood_lldp_frames
    @topology.each_switch do |dpid, ports|
     if dpid.class == Fixnum
      send_lldp dpid, ports
     end
    end
  end

  def send_lldp(dpid, ports)
    ports.each do |each|
      port_number = each.number
      send_packet_out(
        dpid,
        actions: SendOutPort.new(port_number),
        data: lldp_binary_string(dpid, port_number)
      )
    end
  end

  def lldp_binary_string(dpid, port_number)
    destination_mac = @command_line.destination_mac
    if destination_mac
      Pio::Lldp.new(dpid: dpid,
                    port_number: port_number,
                    destination_mac: destination_mac.value).to_binary
    else
      Pio::Lldp.new(dpid: dpid, port_number: port_number).to_binary
    end
  end

  def search_port src, dest, topology
    topology.each_link do |each|
      if ((each.dpid_a.to_s == dest.to_s) && (each.dpid_b.to_s == src.to_s))
        return each.port_b
      end
    end
  end


  def search_ip_port dpid, topology
    topology.each_link do |each|
      if each.dpid_a.to_s == dpid.to_s
        return each.port_b
      end
    end
  end


  def search_node dpid, topology
    topology.each_link do |each|
      if each.dpid_a.to_s == dpid.to_s
        return each.dpid_b
      end
    end
  end

end

### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
