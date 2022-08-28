package main;
use strict;
use warnings;
use IO::Socket::INET; # for TCP client connection
use List::Util 'sum';

# use List::MoreUtils qw(first_index);

## API from https://osswww.ecowitt.net/uploads/20210716/WN1900%20GW1000,1100%20WH2680,2650%20telenet%20v1.6.0%20.pdf
my %GW1000_cmdMap = (
	CMD_WRITE_SSID 				=> 0x11,		# send SSID and Password to WIFI module
	CMD_BROADCAST 				=> 0x12,		# UDP cast for device echo，answer back data size is 2 Bytes
	CMD_READ_ECOWITT 			=> 0x1E,		# read aw.net setting
	CMD_WRITE_ECOWITT 			=> 0x1F,		# write back awt.net setting
	CMD_READ_WUNDERGROUND 		=> 0x20,		# read Wunderground setting
	CMD_WRITE_WUNDERGROUND 		=> 0x21,		# write back Wunderground setting
	CMD_READ_WOW 				=> 0x22,		# read WeatherObservationsWebsite setting
	CMD_WRITE_WOW 				=> 0x23,		# write back WeatherObservationsWebsite setting
	CMD_READ_WEATHERCLOUD 		=> 0x24,		# read Weathercloud setting
	CMD_WRITE_WEATHERCLOUD 		=> 0x25,		# write back Weathercloud setting
	CMD_READ_STATION_MAC		=> 0x26,		# read MAC address
	CMD_READ_CUSTOMIZED 		=> 0x2A,		# read Customized sever setting
	CMD_WRITE_CUSTOMIZED 		=> 0x2B,		#  write back Customized sever setting
	CMD_WRITE_UPDATE 			=> 0x43,		# firmware upgrade
	CMD_READ_FIRMWARE_VERSION 	=> 0x50,		# read current firmware version number
	CMD_READ_USR_PATH 			=> 0x51,		
	CMD_WRITE_USR_PATH 			=> 0x52,		
	CMD_GW1000_LIVEDATA 		=> 0x27,		# read current data，reply data size is 2bytes. only valid for GW1000, WH2650 and wn1900
	CMD_GET_SOILHUMIAD 			=> 0x28,		# read Soilmoisture Sensor calibration parameters
	CMD_SET_SOILHUMIAD 			=> 0x29,		# write back Soilmoisture Sensor calibration parameters
	CMD_GET_MulCH_OFFSET 		=> 0x2C,		# read multi channel sensor offset value
	CMD_SET_MulCH_OFFSET 		=> 0x2D,		# write back multi channel sensor OFFSET value
	CMD_GET_PM25_OFFSET 		=> 0x2E,		# read PM2.5OFFSET calibration data
	CMD_SET_PM25_OFFSET 		=> 0x2F,		# writeback PM2.5OFFSET calibration data
	CMD_READ_SSSS 				=> 0x30,		# read system info
	CMD_WRITE_SSSS 				=> 0x31,		# write back system info
	CMD_READ_RAINDATA 			=> 0x34,		# read rain data
	CMD_WRITE_RAINDATA 			=> 0x35,		# write back rain data
	CMD_READ_GAIN 				=> 0x36,		# read rain gain
	CMD_WRITE_GAIN 				=> 0x37,		# write back rain gain
	CMD_READ_CALIBRATION 		=> 0x38,		# read sensor set offset calibration value
	CMD_WRITE_CALIBRATION 		=> 0x39,		# write back sensor set offset value
	CMD_READ_SENSOR_ID 			=> 0x3A,		# read Sensors ID
	CMD_WRITE_SENSOR_ID 		=> 0x3B,		# write back Sensors ID
	CMD_READ_SENSOR_ID_NEW 		=> 0x3C,		# this is reserved for newly added sensor
	CMD_WRITE_REBOOT 			=> 0x40,		# system restart
	CMD_WRITE_RESET 			=> 0x41,		# reset to default
	CMD_READ_FIRMWARE_VERSION	=> 0x50,		# frimware version
	CMD_READ_CUSTOMIZED_PATH 	=> 0x51,		
	CMD_WRITE_CUSTOMIZED_PATH 	=> 0x52,		
	CMD_GET_CO2_OFFSET 			=> 0x53,		# CO2 OFFSET
	CMD_SET_CO2_OFFSET 			=> 0x54,		# CO2 OFFSET
);
my %GW1000_cmdMap_reversed = reverse %GW1000_cmdMap;

my %GW1000_Items = (
	0x01 => {name => "Indoor Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x02 => {name => "Outdoor Temperature", 		size => 2, isSigned => 1, factor => 1, unit => "°C"}, 
	0x03 => {name => "Dew point",		 			size => 2, isSigned => 0, factor => 1, unit => "°C"}, 
	0x04 => {name => "Wind chill", 					size => 2, isSigned => 0, factor => 1, unit => "°C"},
	0x05 => {name => "Heat index", 					size => 2, isSigned => 0, factor => 1, unit => "°C"},
	0x06 => {name => "Indoor Humidity", 			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x07 => {name => "Outdoor Humidity", 			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x08 => {name => "Absolutely Barometric ", 		size => 2, isSigned => 0, factor => 0.1, unit => "hpa"}, 
	0x09 => {name => "Relative Barometric", 		size => 2, isSigned => 0, factor => 0.1, unit => "hpa"},
	0x0A => {name => "Wind Direction", 				size => 2, isSigned => 0, factor => 1, unit => "360°"},
	0x0B => {name => "Wind Speed ", 				size => 2, isSigned => 0, factor => 1, unit => "m/s"}, 
	0x0C => {name => "Gust Speed", 					size => 2, isSigned => 0, factor => 1, unit => "m/s"}, 
	0x0D => {name => "Rain Event", 					size => 2, isSigned => 0, factor => 1, unit => "mm"}, 
	0x0E => {name => "Rain Rate", 					size => 2, isSigned => 0, factor => 1, unit => "mm/h"},
	0x0F => {name => "Rain hour ", 					size => 2, isSigned => 0, factor => 1, unit => "mm"}, 
	0x10 => {name => "Rain Day", 					size => 2, isSigned => 0, factor => 1, unit => "mm"}, 
	0x11 => {name => "Rain Week", 					size => 2, isSigned => 0, factor => 1, unit => "mm"}, 
	0x12 => {name => "Rain Month", 					size => 4, isSigned => 0, factor => 1, unit => "mm"}, 
	0x13 => {name => "Rain Year", 					size => 4, isSigned => 0, factor => 1, unit => "mm"}, 
	0x14 => {name => "Rain Totals", 				size => 4, isSigned => 0, factor => 1, unit => "mm"}, 
	0x15 => {name => "Light", 						size => 4, isSigned => 0, factor => 1, unit => "lux"}, 
	0x16 => {name => "UV", 							size => 2, isSigned => 0, factor => 1, unit => "uW/m2"}, 
	0x17 => {name => "UVI", 						size => 1, isSigned => 0, factor => 1, unit => "0-15 index"},
	0x18 => {name => "Date and time",				size => 6, isSigned => 0, factor => 1, unit => "-"},
	0x19 => {name => "Day max wind", 				size => 2, isSigned => 0, factor => 1, unit => "m/s"}, 
	0x1A => {name => "CH1 Temperature",				size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x1B => {name => "CH2 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x1C => {name => "CH3 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x1D => {name => "CH4 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x1E => {name => "CH5 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x1F => {name => "CH6 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x20 => {name => "CH7 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x21 => {name => "CH8 Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x22 => {name => "CH1 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x23 => {name => "CH2 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x24 => {name => "CH3 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x25 => {name => "CH4 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x26 => {name => "CH5 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x27 => {name => "CH6 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x28 => {name => "CH7 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x29 => {name => "CH8 Humidity", 				size => 1, isSigned => 0, factor => 1, unit => "0-100%"},
	0x2A => {name => "PM2.5 Air Quality Sensor",	size => 2, isSigned => 0, factor => 1, unit => "μg/m3"},  
	0x2B => {name => "Soil Temperature", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x2C => {name => "Soil Moisture", 				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x2D => {name => "Soil Temperature 1", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x2E => {name => "Soil Moisture 1",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x2F => {name => "Soil Temperature 2", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x30 => {name => "Soil Moisture 2",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x31 => {name => "Soil Temperature 3", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x32 => {name => "Soil Moisture 3",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x33 => {name => "Soil Temperature 4", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x34 => {name => "Soil Moisture 4",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x35 => {name => "Soil Temperature 5", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x36 => {name => "Soil Moisture 5",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x37 => {name => "Soil Temperature 6", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x38 => {name => "Soil Moisture 6", 			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x39 => {name => "Soil Temperature 7", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x3A => {name => "Soil Moisture 7",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x3B => {name => "Soil Temperature 8", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x3C => {name => "Soil Moisture 8",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x3D => {name => "Soil Temperature 9", 			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x3E => {name => "Soil Moisture 9",				size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x3F => {name => "Soil Temperature 10",			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x40 => {name => "Soil Moisture 10",			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x41 => {name => "Soil Temperature 11",			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x42 => {name => "Soil Moisture 11",			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x43 => {name => "Soil Temperature 12",			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x44 => {name => "Soil Moisture 12", 			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x45 => {name => "Soil Temperature 13",			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x46 => {name => "Soil Moisture 13",  			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x47 => {name => "Soil Temperature 14",			size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x48 => {name => "Soil Moisture 14",			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x49 => {name => "Soil Temperature 15", 		size => 2, isSigned => 1, factor => 0.1, unit => "°C"},
	0x4A => {name => "Soil Moisture 15",			size => 1, isSigned => 0, factor => 1, unit => "%"}, 
	0x4C => {name => "All sensor lowbatt", 			size => 16, isSigned => 0, factor => 1, unit => "-"}, 
	0x4D => {name => "pm25 24HAVG1", 				size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x4E => {name => "pm25 24HAVG2", 				size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x4F => {name => "pm25 24HAVG3", 				size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x50 => {name => "pm25 24HAVG4", 				size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x51 => {name => "PM2.5 Air Quality Sensor 2", 	size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x52 => {name => "PM2.5 Air Quality Sensor 3", 	size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x53 => {name => "PM2.5 Air Quality Sensor 4", 	size => 2, isSigned => 0, factor => 1, unit => "-"}, 
	0x58 => {name => "Leak_ch1", 					size => 1, isSigned => 0, factor => 1, unit => "-"}, 
	0x59 => {name => "Leak_ch2", 					size => 1, isSigned => 0, factor => 1, unit => "-"}, 
	0x5A => {name => "Leak_ch3", 					size => 1, isSigned => 0, factor => 1, unit => "-"}, 
	0x5B => {name => "Leak_ch4", 					size => 1, isSigned => 0, factor => 1, unit => "-"}, 
	0x60 => {name => "lightning distance", 			size => 1, isSigned => 0, factor => 1, unit => "1~40km"},  
	0x61 => {name => "lightning happened time", 	size => 4, isSigned => 0, factor => 1, unit => "UTC"}, 
	0x62 => {name => "lightning counter for the day", size => 4, isSigned => 0, factor => 1, unit => "-"}, 
	
	0x63 => {name => "TF USR Temperature 1", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x64 => {name => "TF USR Temperature 2", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x65 => {name => "TF USR Temperature 3", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x66 => {name => "TF USR Temperature 4", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x67 => {name => "TF USR Temperature 5", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x68 => {name => "TF USR Temperature 6", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x69 => {name => "TF USR Temperature 7", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	0x6A => {name => "TF USR Temperature 8", 		size => 4, isSigned => 0, factor => 1, unit => "°C"},
	
	0x72 => {name => "Leaf Wetness 1", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x73 => {name => "Leaf Wetness 2", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x74 => {name => "Leaf Wetness 3", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x75 => {name => "Leaf Wetness 4", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x76 => {name => "Leaf Wetness 5", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x77 => {name => "Leaf Wetness 6", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x78 => {name => "Leaf Wetness 7", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
	0x79 => {name => "Leaf Wetness 8", 				size => 1, isSigned => 0, factor => 1, unit => "-"},
);

my @GW1000_header = (0xff, 0xff);

my %attributeMap = (
	connectTimeout => 'connectTimeout',
	updateIntervall => 'updateIntervall',
);

sub GW1000_TCP_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}      = 'GW1000_TCP_Define';
    $hash->{UndefFn}    = 'GW1000_TCP_Undef';
    $hash->{SetFn}      = 'GW1000_TCP_Set';
    $hash->{GetFn}      = 'GW1000_TCP_Get';
    $hash->{AttrFn}     = 'GW1000_TCP_Attr';
    $hash->{ReadFn}     = 'GW1000_TCP_Read';
    $hash->{NotifyFn}   = "GW1000_TCP_Notify";

    #TODO fill AttrList from %attributeMap
    $hash->{AttrList} =
          "lircd_codes:textField-long "
        . join(' ', values %attributeMap). " "   #add attributes from %attributeMap
        . $readingFnAttributes;

}

sub GW1000_TCP_Define($$) {
	my ($hash, $def) = @_;
	my @param = split('[ \t]+', $def);

	#set default values
	$hash->{I_GW1000_Port} = '45000';
	
	#read defines
	if(int(@param) < 3) {
		return "too few parameters: define <name> GW1000_TCP <IP> <Port>";
	}

	$hash->{name}  = $param[0];
	$hash->{I_GW1000_IP} = $param[2];
	
	#$hash->{helper}{ir_codes_hash} = {KEY_UNKNOWN => '0x0'};
	#$hash->{helper}{ir_codes_revhash} = {'0x0' => 'KEY_UNKNOWN'};

	#check input parameters
	if($init_done) {
		#my $return_value = check_I_SourceModule($hash);
		#return $return_value if (defined $return_value);
	}

	#if(!(exists $protocolTypes{$hash->{I_IrProtocolName}})) {
	#	my $err = "Invalid ProtocolName $hash->{I_IrProtocolName}. Must be one of " . join(', ', keys %protocolTypes);
	#	Log 3, "UniversalRemoteIR <$hash->{name}>: ".$err;
	#	return $err;
	#}

	#limit reaction on notify
	$hash->{NOTIFYDEV} = "global";
	
	#start cyclic update of GW1000
	GW1000_TCP_GetUpdate($hash);
	
	return undef;
}

sub GW1000_TCP_Undef($$) {
	my ($hash, $arg) = @_;
	
	# delete timer
	RemoveInternalTimer($hash, "GW1000_TCP_GetUpdate");
	
	return undef;
}

sub GW1000_TCP_Get($@) {
	my ($hash, @param) = @_;	
	
	return '"get UniversalRemoteIR" needs at least one argument' if (int(@param) < 2);	
	
	my $name = shift @param;
	my $opt = shift @param;	
	
	return ;
}

sub GW1000_TCP_Set($@) {
	my ( $hash, $name, $cmd, @args ) = @_;

	return "\"set $name\" needs at least one argument" unless(defined($cmd));

	my $cmd_list = "";
	$cmd_list .= "send:select," . join(',', sort(keys(%{$hash->{helper}{ir_codes_hash}}))) . " ";
	$cmd_list .= "loadLircdConfig ";

	if($cmd eq "loadLircdConfig") {

	}
	elsif ($cmd eq "send") {
		#set readings
	  	#readingsSingleUpdate($hash, "lastCommand", $args[0], 1);
	}
	else {
		return "Unknown argument $cmd, choose one of $cmd_list";
	}
}

sub GW1000_TCP_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	my $hash = $defs{$name};

	if($cmd eq "set") {
		if($attr_name eq "lircd_codes") {
		}
		#TODO handle all attributes from attrMap
	}
	return undef;
}

sub GW1000_TCP_Notify($$)
{
	my ($hash, $dev_hash) = @_;
	my $ownName = $hash->{NAME}; # own name / hash

	return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
	
	my $devName = $dev_hash->{NAME}; # Device that created the events
	
	my $events = deviceEvents($dev_hash,1);
	return if( !$events );

	if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events})) {
		#start cyclic update of GW1000
		GW1000_TCP_GetUpdate($hash);
	}
	
}

sub GW1000_TCP_GetUpdate($)
{
	my ($hash) = @_;
	my $name = $hash->{NAME};
	Log3 $name, 4, "GW1000_TCP: GetUpdate called ...";
	
	my ($cmd, @data) = requestData($hash, $GW1000_cmdMap{CMD_READ_STATION_MAC}, 0);
	updateData($hash, $cmd, @data );
	
	($cmd, @data) = requestData($hash, $GW1000_cmdMap{CMD_GW1000_LIVEDATA}, 0);
	updateData($hash, $cmd, @data );
	
	($cmd, @data) = requestData($hash, $GW1000_cmdMap{CMD_READ_FIRMWARE_VERSION}, 0);
	updateData($hash, $cmd, @data );
	
		
	# start new timer.
	InternalTimer(gettimeofday()+AttrVal($name, "updateIntervall", 16), "GW1000_TCP_GetUpdate", $hash);
}

##aux functions
sub requestData($$@) {
	my ($hash, $cmd, @data) = @_;
	my $name = $hash->{name};
	
	my $err = "";
	
	# create a connecting socket
	my $socket = new IO::Socket::INET (
    	PeerHost => $hash->{I_GW1000_IP},
    	PeerPort => $hash->{I_GW1000_Port},
    	Proto => 'tcp',
		Timeout => AttrVal($name, "connectTimeout", 1),
	);
	
	if($socket) {
    	$hash->{STATE} = "Connected";
    	Log 2, "GW1000_TCP <$hash->{name}>: connected to server ($hash->{I_GW1000_IP}:$hash->{I_GW1000_Port})" ;

  	} else {
		$hash->{STATE} = "Disconnected";
		Log 2, "GW1000_TCP <$hash->{name}>: connection failed to server ($hash->{I_GW1000_IP}:$hash->{I_GW1000_Port})";
		return 0;
	}	
	
	$socket->autoflush(1);

	# data to send to a server
	my @packet;
	push(@packet, @GW1000_header);
	push(@packet, $cmd);
	push(@packet, scalar(@data) + 3);
	push(@packet, @data);
	push(@packet, sum(@packet) - sum(@GW1000_header));
	
	my $req = pack('C*', @packet);

	my $size = $socket->send($req);
	Log 2, "GW1000_TCP <$hash->{name}>: sent data (size: $size):" . unpack('H*', $req);

	# notify server that request has been sent
	shutdown($socket, 1);

	# receive a response of up to 1024 characters from server
	my $response_string = "";
	$socket->recv($response_string, 1024);
	my @response = unpack('(C)*', $response_string);
	Log 2, "GW1000_TCP <$hash->{name}>: received response: " . unpack('H*', $response_string) . " (@response)";

	$socket->close();
	
	# unpack response
	my @response_header = (shift(@response), shift(@response));
	my $response_cmd = shift(@response);
	my $response_size = 0;
	my $sizeOfsize = 0;
	if ($response_cmd == $GW1000_cmdMap{CMD_BROADCAST} || $response_cmd == $GW1000_cmdMap{CMD_GW1000_LIVEDATA}) {
		# size is 2 byte
		$response_size = shift(@response) * 256 + shift(@response);
		$sizeOfsize = 2;
	} else {
		# size is 1 byte
		$response_size = shift(@response);
		$sizeOfsize = 1;
	}
	
	my $response_cs = pop(@response);
	my @response_data = @response;
	
	$err = sprintf("HEADER: 0x%x 0x%x; CMD: 0x%x; SIZE: $response_size; CHECKSUM: $response_cs; DATA: @response_data", $response_header[0], $response_header[1], $response_cmd);
	Log 2, "GW1000_TCP <$hash->{name}>: $err";
	
	#check fixed header = 0xffff
	if ($response_header[0] != 0xff || $response_header[1] != 0xff) {
		$err = sprintf("ERROR: fixed header is 0x%x 0x%x ! (Should be '0xff 0xff')", $response_header[0], $response_header[1]);
		Log 1, "GW1000_TCP <$hash->{name}>: $err";
		return;
	};
	
	#check cmd is same as requested
	if ($response_cmd != $cmd) {
		$err = sprintf("ERROR: receved not requested dataset (requested: 0x%x; received: 0x%x)", $cmd, $response_cmd);
		Log 1, "GW1000_TCP <$hash->{name}>: $err";
		return;
	};
	
	#check size (SIZE: 1 byte, packet size，counted from CMD till CHECKSUM)
	## REMARK some packages have size/2
	my $size_calc = scalar(@response_data) + 2 + $sizeOfsize;
	if ($response_size != $size_calc) {
		$err = sprintf("ERROR: response size is not equal to size reported in response (reported: $response_size; actual: $size_calc)");
		Log 1, "GW1000_TCP <$hash->{name}>: $err";
		return;
	};
	
	
	#check checksum (CHECKSUM: 1 byte, CHECKSUM=CMD+SIZE+DATA1+DATA2+...+DATAn)
	###DISABLE checksum test, sinceits not clear how it is calculated
	#my $cs_calc = ($response_cmd + $response_size + sum(@response_data)) % 255;
	#if ($response_cs != $cs_calc) {
	#	$err = sprintf("ERROR: response checksum is not equal to chescksum reported in response (reported: $response_cs; actual: $cs_calc)");
	#	Log 1, "GW1000_TCP <$hash->{name}>: $err";
	#	return;
	#};

	return $response_cmd, @response_data;
}

sub updateData($$@) {
	my ($hash, $cmd, @data) = @_;
	
	my $name = $hash->{name};
	my $msg = "";
	
	$msg = sprintf("Received %s (0x%x). Unpacking data...",  $GW1000_cmdMap_reversed{$cmd}, $cmd);	
	Log3($name, 2, "GW1000_TCP: $msg"); 
	
	if ($cmd == $GW1000_cmdMap{CMD_READ_STATION_MAC}) {
		
		readingsSingleUpdate($hash, "StationMac", sprintf("%x %x %x %x %x %x", @data), 1 );
	}
	#elsif ($cmd == $GW1000_cmdMap{CMD_READ_FIRMWARE_VERSION}) {
		shift(@data);
		my $x = join '', map chr, @data;
		readingsSingleUpdate($hash, "Firmware Version", sprintf("%s" , $x), 1 );
	}
	elsif ($cmd == $GW1000_cmdMap{CMD_GW1000_LIVEDATA}) {
				
		readingsBeginUpdate($hash);
		while (my $item = shift(@data)) {
		
			if (exists($GW1000_Items{$item})) {
				my $value = 0;
				for (my $i = $GW1000_Items{$item}{size} - 1; $i >= 0; $i--) {
					$value += shift(@data) * 2**(8*$i);
				}
				if ( $GW1000_Items{$item}{isSigned}) {
					if    ($GW1000_Items{$item}{size} == 1) {$value = unpack('c', pack('C', $value));}
					elsif ($GW1000_Items{$item}{size} == 2) {$value = unpack('s', pack('S', $value));}
					elsif ($GW1000_Items{$item}{size} == 4) {$value = unpack('q', pack('Q', $value));}
					else {
						$msg = sprintf("ERROR: Received %s (0x%x) but don't know how to convert value of size %d to signed integer. Skipping...", $GW1000_Items{$item}{name}, $item, $GW1000_Items{$item}{size});	
						Log3($name, 2, "GW1000_TCP: $msg"); 
					}
				}
			 
				$value *= $GW1000_Items{$item}{factor};
				
				$msg = sprintf("Received %s (0x%x) = %2.1f",  $GW1000_Items{$item}{name}, $item, $value);	
				Log3($name, 2, "GW1000_TCP: $msg"); 
				readingsBulkUpdate($hash, $GW1000_Items{$item}{name}, sprintf("%2.1f", $value) );
			} else {
				$msg = sprintf("Item (0x%x) is unknown. Skipping complete package!", $item);
				Log3($name, 2, "GW1000_TCP: $msg"); 
				readingsEndUpdate($hash, 1);
				return 1;
			}
			
		}
		readingsEndUpdate($hash, 1);
	}
	else {
		Log3($name, 2, "GW1000_TCP: Unkown data received. Skipping!"); 
		
	}
	
	return 1;	
}

1;

