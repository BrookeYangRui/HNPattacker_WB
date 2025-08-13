import python
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking
import semmle.python.dataflow.new.RemoteFlowSources
import semmle.python.Concepts
import semmle.python.frameworks.Flask

module RemoteToFileConfiguration implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    //source instanceof RemoteFlowSource
    exists(Expr e |
    source.asExpr() = e 
    and e.toString().regexpMatch(".*url_for.*")
  )
  }

  predicate isSink(DataFlow::Node sink) {
    sink = any(FileSystemAccess fa).getAPathArgument()
  }
}

module RemoteToFileFlow = TaintTracking::Global<RemoteToFileConfiguration>;

from DataFlow::Node input, DataFlow::Node fileAccess
where RemoteToFileFlow::flow(input, fileAccess)
select fileAccess, "This file access uses data from $@.",
  input, "user-controllable input."

// module HostHeaderSource implements DataFlow::ConfigSig {
//   predicate isSource(DataFlow::Node node) {
//     // source instanceof RemoteFlowSource
//     node request()
//   }

//   predicate isSink(DataFlow::Node sink) {
//     sink = any(FileSystemAccess fa).getAPathArgument()
//   }
// }

// module RemoteToFileFlow = TaintTracking::Global<RemoteToFileConfiguration>;

// from DataFlow::Node input, DataFlow::Node fileAccess
// where RemoteToFileFlow::flow(input, fileAccess)
// select fileAccess, "This file access uses data from $@.",
//   input, "user-controllable input."


// class DangerousSink extends RemoteFlowSink::Range {
//   DangerousSink() {
//     // Detect where host is used in redirect or URL construction
//     exists(CallExpr c |
//       c.getFunc().getName().regexpMatch("redirect|url_for|make_url") and
//       thisFlow = c.getArg(0)
//     )
//   }
// }

// from HostHeaderSource src, DangerousSink sink
// where src.flowTo(sink)
// select sink, "Host header flows into unsafe URL/redirect → possible Hostname Pollution."
