class MyController < Controller
	
	###################
	# read rule from configuration file
	##################
	def start
		@rules = Hash.new
	end

	###################
	#send rule to switch
	#for every pkt that enters the switch, send it to controller
	#let icmp and arp packets pass directly
	###################
	def switch_ready datapath_id
		#allow arp and icmp packets
		dl_type_arp = 0x0806
		dl_type_ipv4 = 0x0800
		dl_type_ipv6 = 0x86dd
		send_flow_mod_add( datapath_id, 
			:match => Match.new( {:dl_type => dl_type_arp } ),
			:actions => ActionOutput.new( OFPP_NORMAL ) 
			)
		send_flow_mod_add( datapath_id,
                        :match => Match.new( {:dl_type => dl_type_ipv4, :nw_proto => 2 } ),
                        :actions => ActionOutput.new( OFPP_NORMAL )
                        )
		send_flow_mod_add( datapath_id, 
			:match => Match.new( {:dl_type => dl_type_ipv4, :nw_proto => 1 } ),
			:actions => ActionOutput.new( OFPP_CONTROLLER ) 
			)
		send_flow_mod_add( datapath_id,
                        :match => Match.new( {:dl_type => dl_type_ipv4, :nw_proto => 6 } ),
                        :actions => ActionOutput.new( OFPP_CONTROLLER )
                        )
		send_flow_mod_add( datapath_id,
                        :match => Match.new( {:dl_type => dl_type_ipv4, :nw_proto => 17 } ),
                        :actions => ActionOutput.new( OFPP_CONTROLLER  )
                        )
		send_flow_mod_add( datapath_id,
                        :match => Match.new( {:dl_type => dl_type_ipv6 } ),
                        :actions => ActionOutput.new( OFPP_NORMAL )
                        )
		puts "rule added to switch for arp and ipv6 pkt: send normally"
	end

	#######################
	# if packet is allowed in the configure file, add a rule to the switch
	# that also allows future packets going through the reverse path
	# else deny it (drop it)
	######################
	def packet_in datapath_id, message
		puts "msg in"
                puts "#{message.ipv4_saddr.to_s} to #{message.ipv4_daddr.to_s}"
                if message.in_port == OFPP_LOCAL
                        out_port = 1
                else
                        out_port = OFPP_LOCAL
                end

                if message.udp?
                        payload = message.udp_payload.split(";")
                        dst = payload[0].split(":").last
                        ctl = payload[1].split(":").last
                        law = payload[2].split(":").last
			@rules[dst] = law
			puts "add rule: #{dst} ==> #{law}"
			@rules[ctl] = law
			puts "add rule: #{ctl} ==> #{law}"
		elsif message.tcp? or message.icmpv4?
			puts "regular"
			if @rules.has_key?( message.ipv4_daddr.to_s )
				puts "match"
				if message.ipv4_saddr.to_s ==  @rules[ message.ipv4_daddr.to_s ]
					puts "pass"
					packet_out datapath_id, message, SendOutPort.new(out_port)
				else
					puts "illegal message"
				end
			else
				puts "not match, so pass"
				packet_out datapath_id, message, SendOutPort.new(out_port)
			end
                end

	end

	def packet_out(datapath_id, message, action)
    		send_packet_out(
      			datapath_id,
      			:in_port => message.in_port,
			:buffer_id => 0xffffffff,
			:data => message.data,
      			:zero_padding => true,
			:actions => action
    		)
	end
	
end
