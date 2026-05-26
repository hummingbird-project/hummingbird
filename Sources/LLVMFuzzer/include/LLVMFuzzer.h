//
// This source file is part of the Hummingbird server framework project
// Copyright (c) the Hummingbird authors
//
// See LICENSE.txt for license information
// SPDX-License-Identifier: Apache-2.0
//

#ifndef _LLVM_FUZZER_H_
#define _LLVM_FUZZER_H_

#include <stddef.h>
#include <stdint.h>

size_t LLVMFuzzerMutate(uint8_t *data, size_t size, size_t maxSize);

#endif /* _LLVM_FUZZER_H_ */