use tiny_keccak::{Keccak, Hasher};

fn main() {
    let target = hex::decode("d9ad5396ce1ed307e8fb2a90de7fd01d888c02950ef6852fbc2191d2baf58e79").unwrap();
    let mut finded = false;
    for w1 in b'a'..=b'z' {
        for w2 in b'a'..=b'z' {
            for w3 in b'a'..=b'z' {
                for w4 in b'a'..=b'z' {
                    let mut hasher = Keccak::v256();
                    let mut output = [0u8; 32];
                    let input = vec![w1,w2,w3,w4,b'm',b'o',b'v',b'e'];
                    hasher.update(input.as_slice());
                    hasher.finalize(&mut output);
                    if output == target.as_slice() {
                        println!("{}", std::str::from_utf8(input.as_slice()).unwrap());
                        finded = true;
                        break;
                    }
                }
                if finded { break };
            }
            if finded { break };
        }
        if finded { break };
    }
}