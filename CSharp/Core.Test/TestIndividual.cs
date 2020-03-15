using System;
using NUnit.Framework;

namespace Business.Core.Test
{
	[TestFixture()]
	public class TestIndividual
	{
		[Test()]
		public void Empty() {
			var individual = new Individual();
			Assert.IsNull(individual.Id);
			Assert.IsNull(individual.Person);
			Assert.IsNull(individual.GoesBy);
			Assert.IsNull(individual.FullName);
		}
	}
}
