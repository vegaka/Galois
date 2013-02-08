/** Wrapper around an iterator such that *it == it -*- C++ -*-
 * @file
 * @section License
 *
 * Galois, a framework to exploit amorphous data-parallelism in irregular
 * programs.
 *
 * Copyright (C) 2013, The University of Texas at Austin. All rights reserved.
 * UNIVERSITY EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES CONCERNING THIS
 * SOFTWARE AND DOCUMENTATION, INCLUDING ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR ANY PARTICULAR PURPOSE, NON-INFRINGEMENT AND WARRANTIES OF
 * PERFORMANCE, AND ANY WARRANTY THAT MIGHT OTHERWISE ARISE FROM COURSE OF
 * DEALING OR USAGE OF TRADE.  NO WARRANTY IS EITHER EXPRESS OR IMPLIED WITH
 * RESPECT TO THE USE OF THE SOFTWARE OR DOCUMENTATION. Under no circumstances
 * shall University be liable for incidental, special, indirect, direct or
 * consequential damages or loss of profits, interruption of business, or
 * related expenses which may arise from use of Software or Documentation,
 * including but not limited to those resulting from defects in Software and/or
 * Documentation, or loss or inaccuracy of data of any kind.
 *
 * @section Description
 *
 * @author Donald Nguyen <ddn@cs.utexas.edu>
 */
#ifndef GALOIS_NODEREFITERATOR_H
#define GALOIS_NODEREFITERATOR_H

#include "boost/iterator/iterator_adaptor.hpp"

namespace Galois {

//! Modify an iterator so that *it == it
template<typename Iterator>
struct NoDerefIterator : public boost::iterator_adaptor<
  NoDerefIterator<Iterator>, Iterator, Iterator, 
  boost::use_default, const Iterator&>
{
  NoDerefIterator(): NoDerefIterator::iterator_adaptor_() { }
  explicit NoDerefIterator(Iterator it): NoDerefIterator::iterator_adaptor_(it) { }
  const Iterator& dereference() const {
    return NoDerefIterator::iterator_adaptor_::base_reference();
  }
  Iterator& dereference() {
    return NoDerefIterator::iterator_adaptor_::base_reference();
  }
};

//! Convenience function to create {@link NoDerefIterator}.
template<typename Iterator>
NoDerefIterator<Iterator> make_no_deref_iterator(Iterator it) {
  return NoDerefIterator<Iterator>(it);
}

}

#endif
