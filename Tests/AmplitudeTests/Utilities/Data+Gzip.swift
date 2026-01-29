//
//  Data+Gzip.swift
//  Amplitude-Swift
//
//  Created by Chris Leonavicius on 1/28/26.
//

import Foundation
import zlib

extension Data {

    /// Gunzips data using zlib (expects gzip wrapper).
    func gunzipped() -> Data? {
        guard !isEmpty else { return Data() }

        var stream = z_stream()
        var status: Int32 = Z_OK

        return withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = src.baseAddress else { return nil }

            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: srcBase.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(count)

            // 15 = max window bits, +16 = gzip wrapper
            status = inflateInit2_(
                &stream,
                15 + 16,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard status == Z_OK else { return nil }
            defer { inflateEnd(&stream) }

            let chunkSize = 64 * 1024
            var output = Data()
            var buffer = Data(count: chunkSize)

            while true {
                let produced: Int = buffer.withUnsafeMutableBytes { dst -> Int in
                    guard let dstBase = dst.baseAddress else { return 0 }

                    stream.next_out = dstBase.assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(dst.count)

                    status = inflate(&stream, Z_NO_FLUSH)

                    return dst.count - Int(stream.avail_out)
                }

                if produced > 0 {
                    output.append(buffer.prefix(produced))
                }

                if status == Z_STREAM_END {
                    return output
                }

                // Inflate returns Z_OK while it needs more input/output space.
                guard status == Z_OK else { return nil }

                // If we produced nothing and status is OK, loop again; zlib may need more room.
            }
        }
    }
}
