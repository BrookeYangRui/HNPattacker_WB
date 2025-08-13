import python
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking
import semmle.python.dataflow.new.RemoteFlowSources
import semmle.python.Concepts
import semmle.python.frameworks.Flask

from Call urlForCall,Keyword kw

where
  urlForCall.getFunc().toString() = "url_for"
  and kw = urlForCall.getAKeyword()
  and kw.getArg().toString() = "_external"
  and kw.getValue().toString() = "True"
select kw.getArg(), kw.getValue()

// from Function func, Call call
// select call